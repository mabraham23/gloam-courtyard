# Jump elbow direction correction — 2026-09-10

The user identified backwards elbow bending in the running jump. The previous
visual verdict was wrong: the increased positive body-X driver extended the
forearms behind the elbow. The old unsigned angle check could not distinguish
that from forward flexion.

Only the jump elbow driver sign changes runtime behavior. Negative body-X folds
the forearms forward (+Z), including preparation and impact recovery. Shoulder
motion, alternating leads, landing compression, jump timing and travel are retained.
The shared rig and frozen assets are unchanged; V1 remains the default.

## Evidence

- `index.html` compares the preserved rejected pose and corrected pose with the
  same 150-frame fixture, seed, renderer, camera and input schedule. Profile frames
  26 and 101 show each lead folding forward. Frame 36 retains the landing catch.
  `gameplay.webp` and `gameplay.jpg` show the corrected default-camera sequence.
- The actual-skeleton elbow test now measures direction using the upper arm's
  transported forward-flexion axis. On the rejected runtime it fails all 12 moving
  cases, with signed minima about -56 degrees. The corrected runtime passes all
  5,646 deformation checks, with moving-flight minima 81.39–82.43 degrees.
  The 18 cases cover standing/both moving leads, all sizes and 30/60 Hz. Existing
  knee, pelvis and floor-contact checks still pass. Logs and case measurements
  preserve both the expected failure and passing correction.
- Default/candidate mechanics 309/311 and transitions 67 pass. Snapshot editor
  import and default startup pass. The sandboxed headless logs contain the known
  macOS system-CA lookup warning and failed user-log rotation/writes. These are
  separate from the game checks; stdout logs are preserved here. No script/resource
  or assertion failures occur
  in the corrected runs. The old signed-test failure is intentional evidence.
- Fresh native `Gloam Courtyard Spike (DEBUG)`, PID 46188, source
  `2dfc70da70c6e2b28dc2588a1c7f37ec69c720b60ed8afc0210d843a1a06e8c3`.
  Native V/F12 captured a stationary jump rising at fixed X/Z; Q crouched after
  recovery. Enlarged R/0/F12 reset was inspected and left open. Selected native
  image hashes match their sidecars, with no changed source files.

## Remaining review

The running sequence uses real controller logic with disclosed scripted held input,
static camera and guard placement. It is not proof of native held input or user
acceptance. The user should review the corrected running jump and landing feel.
No new performance certificate or broader action-pose correction is claimed.
Both local boards are regenerated and schema checked; the separate existing board
URL-policy gate remains open. Earlier evidence is preserved, including the rejected
`2026-09-10-running-jump-impact` checkpoint.
