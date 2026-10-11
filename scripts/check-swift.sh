#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
checks_dir="$(mktemp -d)"
trap 'rm -rf "$checks_dir"' EXIT
run_check() {
  local name="$1"
  shift
  swiftc "$@" "Tests/$name.swift" -o "$checks_dir/$name"
  "$checks_dir/$name"
}
run_check HabitatStateChecks EcoGotchi/Models/HabitatState.swift
run_check HabitatStoreChecks EcoGotchi/Models/HabitatState.swift EcoGotchi/Models/RecyclingVerification.swift EcoGotchi/Models/HabitatStore.swift
run_check HabitatExpansionChecks EcoGotchi/Models/HabitatState.swift
run_check PetMotionChecks EcoGotchi/Models/PetMotion.swift
run_check RecyclingCaptureChecks EcoGotchi/Models/RecyclingVerification.swift EcoGotchi/Models/RecyclingCaptureDraft.swift
run_check RecyclingLocationChecks EcoGotchi/Models/RecyclingLocations.swift
run_check VerificationConnectionChecks EcoGotchi/Models/RecyclingVerification.swift EcoGotchi/Models/VerificationConnection.swift
run_check NativeParityChecks EcoGotchi/Models/HabitatState.swift EcoGotchi/Models/HabitatStore.swift EcoGotchi/Models/PetMotion.swift EcoGotchi/Models/AnimalWorld.swift EcoGotchi/Models/AnimalExpressions.swift EcoGotchi/Models/RecyclingVerification.swift EcoGotchi/Models/RecyclingLocations.swift EcoGotchi/Models/VerificationConnection.swift EcoGotchi/Models/CommunityBins.swift
