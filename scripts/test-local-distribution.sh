#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="$(cd -- "$script_dir/.." && pwd)"
launcher="${INIR_LAUNCHER_PATH:-$runtime_root/scripts/inir}"

run_runtime=false
if [[ "${1:-}" == "--with-runtime" ]]; then
    run_runtime=true
fi

step() {
    printf '\n== %s ==\n' "$1"
}

step "shell syntax"
bash -n \
    "$runtime_root/setup" \
    "$runtime_root/scripts/inir" \
    "$runtime_root/sdata/lib/"*.sh \
    "$runtime_root/sdata/subcmd-install/"*.sh \
    "$runtime_root/sdata/migrations/"*.sh

step "runtime payload manifests"
while IFS= read -r runtime_file; do
    [[ -n "$runtime_file" ]] || continue
    [[ -f "$runtime_root/$runtime_file" ]]
done < "$runtime_root/sdata/runtime-root-files.txt"

while IFS= read -r runtime_dir; do
    [[ -n "$runtime_dir" ]] || continue
    [[ -d "$runtime_root/$runtime_dir" ]]
done < "$runtime_root/sdata/runtime-payload-dirs.txt"

step "mascot runtime manifest"
mascot_manifest="$runtime_root/assets/images/mascot/manifest.json"
if [[ ! -f "$mascot_manifest" ]]; then
    printf 'FAIL: mascot runtime manifest is missing: %s\n' "$mascot_manifest" >&2
    exit 1
fi
python3 -m json.tool "$mascot_manifest" >/dev/null
if ! grep -qx 'assets' "$runtime_root/sdata/runtime-payload-dirs.txt"; then
    printf 'FAIL: assets is absent from runtime-payload-dirs.txt\n' >&2
    exit 1
fi
if grep -q -- "--exclude='assets/images/mascot/manifest.json'" "$runtime_root/sdata/lib/functions.sh"; then
    printf 'FAIL: repo-copy sync excludes the mascot runtime manifest\n' >&2
    exit 1
fi
for local_mascot_path in \
    "assets/images/mascot/*.png" \
    "assets/images/mascot/*.gif" \
    "assets/images/mascot/frames/" \
    "assets/images/mascot/PROMPTS.md"; do
    if ! grep -Fq -- "--exclude='$local_mascot_path'" "$runtime_root/sdata/lib/functions.sh"; then
        printf 'FAIL: repo-copy sync can leak local mascot artifact: %s\n' "$local_mascot_path" >&2
        exit 1
    fi
done
if ! grep -q "inir-mascot-.*\\.png" "$runtime_root/Makefile" \
        || ! grep -q "inir-mascot-.*\\.gif" "$runtime_root/Makefile" \
        || ! grep -q 'PROMPTS.md' "$runtime_root/Makefile" \
        || ! grep -q 'assets/images/mascot/frames' "$runtime_root/Makefile"; then
    printf 'FAIL: make install does not strip local mascot art/tooling\n' >&2
    exit 1
fi

if [[ -f "$runtime_root/Makefile" ]]; then
    step "make install dry run"
    make -n install PREFIX=/tmp/inir-stage-test -C "$runtime_root" >/dev/null
fi

if [[ -d "$runtime_root/distro/arch" ]]; then
    step "pkgbuild syntax"
    bash -n \
        "$runtime_root/distro/arch/inir-shell/PKGBUILD" \
        "$runtime_root/distro/arch/inir-shell-git/PKGBUILD" \
        "$runtime_root/distro/arch/inir-meta/PKGBUILD"

    step "version consistency"
    version="$(cat "$runtime_root/VERSION")"
    for pkg in inir-shell inir-meta; do
        pkg_ver="$(grep -m1 '^pkgver=' "$runtime_root/distro/arch/$pkg/PKGBUILD" | cut -d= -f2)"
        if [[ "$pkg_ver" != "$version" ]]; then
            printf 'FAIL: %s pkgver=%s != VERSION=%s\n' "$pkg" "$pkg_ver" "$version" >&2
            exit 1
        fi
    done
fi

step "launcher resolution"
bash "$launcher" path >/dev/null
bash "$launcher" status >/dev/null

if command -v python3 &>/dev/null && [[ -f "$runtime_root/scripts/lib/generate-ipc-registry.py" ]]; then
    step "IPC registry freshness"
    python3 "$runtime_root/scripts/lib/generate-ipc-registry.py" --check
fi

if [[ "$run_runtime" == true ]]; then
    step "runtime restart"
    bash "$runtime_root/scripts/inir" kill >/dev/null 2>&1 || true
    sleep 1
    bash "$runtime_root/scripts/inir" run >/tmp/inir-test-local-runtime.log 2>&1 &
    sleep 3

    step "runtime logs"
    bash "$runtime_root/scripts/inir" logs

    step "runtime filtered errors"
    bash "$launcher" logs --full | grep -iE 'error|ReferenceError|TypeError|binding loop' | tail -80 || true

    step "launcher ipc"
    bash "$launcher" ipc shellUpdate diagnose >/dev/null
fi

step "agent artifact leak guard"
# The source tree legitimately has AGENTS.md/CLAUDE.md in payload dirs.
# Distribution stripping removes them post-copy. Validate the stripping
# contracts exist so no install path can miss them.
leak_guard=0
agent_files=(AGENTS.md CLAUDE.md CODEX.md PI.md codemap.md .mcp.json opencode.json skills-lock.json)
agent_dirs=(.claude .factory .opencode .codex .agents .codebase-memory .impeccable .pi-subagents)

# Makefile must strip agent files after cp -a
for agent_file in "${agent_files[@]}"; do
    if ! grep -q -- "-name $agent_file" "$runtime_root/Makefile" 2>/dev/null; then
        printf 'LEAK GUARD: Makefile missing strip for %s\n' "$agent_file" >&2
        leak_guard=1
    fi
done
for agent_dir in "${agent_dirs[@]}"; do
    if ! grep -q -- "-name $agent_dir" "$runtime_root/Makefile" 2>/dev/null; then
        printf 'LEAK GUARD: Makefile missing strip for %s/\n' "$agent_dir" >&2
        leak_guard=1
    fi
done
if ! grep -q -- '-delete' "$runtime_root/Makefile" 2>/dev/null; then
    printf 'LEAK GUARD: Makefile missing agent-file strip after payload copy\n' >&2
    leak_guard=1
fi
# rsync-based install (sdata/lib/functions.sh) must exclude agent files
if [[ -f "$runtime_root/sdata/lib/functions.sh" ]]; then
    for agent_file in "${agent_files[@]}"; do
        [[ "$agent_file" == .mcp.json || "$agent_file" == opencode.json ]] && continue
        if ! grep -q -- "--exclude='$agent_file'" "$runtime_root/sdata/lib/functions.sh" 2>/dev/null; then
            printf 'LEAK GUARD: sdata/lib/functions.sh missing %s rsync exclude\n' "$agent_file" >&2
            leak_guard=1
        fi
    done
    for agent_dir in "${agent_dirs[@]}"; do
        if ! grep -q -- "--exclude='$agent_dir/'" "$runtime_root/sdata/lib/functions.sh" 2>/dev/null; then
            printf 'LEAK GUARD: sdata/lib/functions.sh missing %s/ rsync exclude\n' "$agent_dir" >&2
            leak_guard=1
        fi
    done
fi
# Agent-only directories must not appear in payload manifests
for agent_dir in "${agent_dirs[@]}"; do
    if grep -qx "$agent_dir" "$runtime_root/sdata/runtime-payload-dirs.txt" 2>/dev/null; then
        printf 'LEAK: %s listed in runtime-payload-dirs.txt\n' "$agent_dir" >&2
        leak_guard=1
    fi
done
for agent_file in "${agent_files[@]}"; do
    if grep -qx "$agent_file" "$runtime_root/sdata/runtime-root-files.txt" 2>/dev/null; then
        printf 'LEAK: %s listed in runtime-root-files.txt\n' "$agent_file" >&2
        leak_guard=1
    fi
done
if [[ "$leak_guard" -eq 1 ]]; then
    printf 'FAIL: agent artifact distribution guard failed\n' >&2
    exit 1
fi

printf '\nAll local distribution checks passed.\n'
