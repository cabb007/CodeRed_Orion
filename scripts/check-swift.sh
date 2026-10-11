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
run_check HabitatStateChecks Recycli/Models/HabitatState.swift
run_check HabitatStoreChecks Recycli/Models/HabitatState.swift Recycli/Models/RecyclingVerification.swift Recycli/Models/HabitatStore.swift
run_check HabitatExpansionChecks Recycli/Models/HabitatState.swift
run_check PetMotionChecks Recycli/Models/PetMotion.swift
run_check RecyclingCaptureChecks Recycli/Models/RecyclingVerification.swift Recycli/Models/RecyclingCaptureDraft.swift
run_check RecyclingLocationChecks Recycli/Models/RecyclingLocations.swift
run_check VerificationConnectionChecks Recycli/Models/RecyclingVerification.swift Recycli/Models/VerificationConnection.swift
run_check NativeParityChecks Recycli/Models/HabitatState.swift Recycli/Models/HabitatStore.swift Recycli/Models/PetMotion.swift Recycli/Models/AnimalWorld.swift Recycli/Models/AnimalExpressions.swift Recycli/Models/RecyclingVerification.swift Recycli/Models/RecyclingLocations.swift Recycli/Models/VerificationConnection.swift Recycli/Models/CommunityBins.swift
run_check CommunityConnectionChecks Recycli/Models/HabitatState.swift Recycli/Models/HabitatStore.swift Recycli/Models/RecyclingVerification.swift Recycli/Models/RecyclingLocations.swift Recycli/Models/VerificationConnection.swift Recycli/Models/CommunityBins.swift
run_check BackgroundReviewChecks Recycli/Models/HabitatState.swift Recycli/Models/RecyclingVerification.swift Recycli/Models/HabitatStore.swift
run_check GeminiReviewChecks Recycli/Models/RecyclingVerification.swift Recycli/Models/VerificationConnection.swift Recycli/Models/GeminiDirectConnection.swift Recycli/Models/GeminiReview.swift
