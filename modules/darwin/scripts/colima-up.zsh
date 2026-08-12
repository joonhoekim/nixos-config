# colima (macOS container runtime). `colima-up` auto-sizes the VM to this
# host so the same function is safe on a big dev Mac and a small 8GB one:
#   CPU = physicalcpu / 2  (clamped 2-8)
#   MEM = memsize / 3 GB   (clamped 2-12)
#   DISK = 60GB fixed
# Backend: Apple Virtualization.framework (vz) + Rosetta (fast amd64
# images) + virtiofs mounts. Extra flags pass through, e.g. `colima-up --edit`.
# NOTE: an already-created colima VM keeps its prior CPU/MEM; run
# `colima delete` first (or `colima stop && colima-up`) to resize.
#
# Sourced into ~/.zshrc (Darwin only) by modules/shared/programs/zsh.nix.
colima-up() {
  local phys mem_total cpu mem
  phys=$(sysctl -n hw.physicalcpu)
  mem_total=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
  cpu=$(( phys / 2 )); (( cpu < 2 )) && cpu=2; (( cpu > 8 )) && cpu=8
  mem=$(( mem_total / 3 )); (( mem < 2 )) && mem=2; (( mem > 12 )) && mem=12
  echo "colima: ${cpu} CPU / ${mem}GB RAM / 60GB disk  (host: ${phys} cores, ${mem_total}GB)"
  colima start --cpu "$cpu" --memory "$mem" --disk 60 \
    --vm-type vz --vz-rosetta --mount-type virtiofs "$@"
}
