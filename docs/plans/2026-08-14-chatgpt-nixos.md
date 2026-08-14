# Implementation plan

1. Add a smoke test for the installed package layout and patched interpreter.
2. Add a flake, pinned upstream metadata, and a Nix derivation for the `.deb`.
3. Add a deterministic updater and scheduled CI workflows.
4. Document one-command profile installation, launching, upgrading, and the
   repository's update/reproducibility guarantees.
5. Run the updater check, `nix flake check`, and a launcher smoke test.
6. Publish the verified repository to GitHub.
