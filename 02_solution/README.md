# 02_solution — Deployable Artifacts

This folder holds the **shipped output** when it is distinct from the development source in `01_Project/`.

## When to use this folder

- Power Platform solution files
- Compiled / bundled output
- Infrastructure-as-Code deploy artifacts
- Static site build output
- Any project where the "shipped thing" is different from the source code

## When this folder stays empty

For standard web apps where `01_Project/` IS the deployment unit (e.g., a Next.js app deployed directly), this folder may remain empty or hold only build output.

## Deployment

Point your deployment config (Docker, Vercel, CI/CD) at this folder when it contains the deploy artifact. If deploying from `01_Project/` instead, exclude this folder or use it as the build output directory.
