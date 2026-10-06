# YabaiSpaces development workflow

After changes that affect YS runtime behavior, build and test them, install the verified build at `/Applications/YabaiSpaces.app`, and restart YS before handing the work back to the user. The user needs the changed behavior running for testing; a successful build alone is not completion. This deployment and restart are authorized by the user's standing instruction.

Before replacement, preserve and verify a backup of the installed app, verify the new build's signature and matching designated requirement, and stop the existing YS process. Verify installed contents and signature, launch the installed app, and confirm the new process and command handling. If a build, installation, or restart fails, report it explicitly and preserve or restore the working app. Never present an uninstalled build as running.

See `docs/SAFE_DEVELOPMENT.md` and `SESSION_LOG.md` for deployment details. Documentation-only changes do not require restarting the app.

Increment the minor application version for published runtime changes, at least before pushing. Keep the installed build and documentation aligned with that version.
