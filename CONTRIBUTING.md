# Contributing

Thanks for helping build our trip app! 🌴

## Workflow

`main` is protected: nobody pushes to it directly, Nelson included. Every change goes through a pull request, and **merging into `main` deploys to the live site automatically**.

1. Create a branch from `main`: `git switch -c feature/short-name`. Fork the repo first if you don't have write access.
2. Make your change and run it locally: the website with [`web/README.md`](web/README.md), the apps with [`ios/README.md`](ios/README.md) or [`android/README.md`](android/README.md).
3. Run the checks for what you touched:
   - website or API: `npm run check` and `npm run build` in `web/`
   - Android: `./gradlew :app:assembleDebug` in `android/`
   - iPhone: build it in Xcode

   CI runs the web checks and the Android build on your PR. The web checks must pass before it can be merged.
4. Open a pull request with a short description. Add screenshots for anything visual, at phone size (about 375 px wide).
5. Once it's merged, the Deploy workflow ships the website and API. Watch it in the Actions tab. App changes reach phones when Nelson installs a new build.

## Guidelines

- **Mobile first.** Most of us use it on the phone, often on the street with a weak connection. Check 375 px width; nothing should scroll sideways.
- **Portuguese UI** (pt-BR) for everything people see, including error messages and `aria-label`s. English for code.
- **Keep the look, in all three apps:** the cozy island and travel theme, dark only.
  - Use the design tokens (`--sea`, `--sun`, `--leaf`, `--coral`…; `Color.sea` in Swift, `Palette.sea` in Kotlin) and the shared icons, not new colors or emoji in the UI.
  - Colors and sizes live in `design/tokens.json`. After changing it, run `node design/build-tokens.mjs`, which regenerates the web CSS, `Theme.swift` and `Tokens.kt`. CI fails if you forget.
  - Icons live in `web/src/lib/components/Icon.svelte`. After changing them, run `node design/build-icons.mjs` for the apps.
- **Change the API, change the apps:** the iPhone and Android apps call the same endpoints. Keep `web/API.md` up to date, and add fields rather than renaming or removing them: phones run older versions until they're reinstalled.
- **Accessibility:** buttons at least 44 px, visible focus, and nothing communicated by color alone.
- **Database changes** go through Drizzle migrations (see `web/README.md`).

## Never commit secrets 🔒

- `.env` files are git-ignored. Keep it that way.
- No real API keys, passwords, tokens, server addresses or anyone's email address in code, tests, issues or PRs.
- App signing stays off the repo: Apple signing lives in Nelson's Xcode. The Android release key (`android/keystore/`, `android/keystore.properties`) lives only on Nelson's Mac, and both are git-ignored.
- If you leaked something by accident, tell Nelson right away. The key has to be rotated; deleting the commit isn't enough.
