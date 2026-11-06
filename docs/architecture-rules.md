# Architecture rules

This is the rulebook for how code in this repo is shaped. [architecture.md](architecture.md) is
the map of what exists today. This file is the law for what may be added. The goal is that the app
still reads as one design after many agents from different people have worked on it, instead of
turning into a pile of one-off patches ("AI spaghetti").

Every change goes through the [architecture review gate](#the-review-gate) (D-014). If a rule here
blocks something you need, propose a change to this file in your design note. Don't work around it.

## Layers

The app has six layers. Code may only depend **downwards** in this table. Never sideways between
features, never upwards.

| # | Layer | Folder | What lives here | May use |
| --- | --- | --- | --- | --- |
| 1 | Composition root | `App/` | `@main`, `RootView` (tabs and navigation between features), `Theme`. Creates every store and provider and injects them. | Everything below |
| 2 | Features | `Features/<Feature>/` | One folder per screen or flow: SwiftUI views and that screen's `@Observable` view model. | Stores, Services (through protocols), Models, `Features/Components` |
| 2a | Shared UI | `Features/Components/` | Reusable views with no feature knowledge (board panel, credit chip, tags). | Models, Theme |
| 3 | Stores | `Stores/` | App-wide `@Observable` state that outlives one screen and is persisted (preferences, species met, likes). | Models, `UserDefaults`/file I/O injected in `init` |
| 4 | Services | `Services/` | **Pure logic** (no I/O): `FeedComposer`, `SpeciesPicker`, `FactExtractor`, `ContentPolicy`. **Adapters** (I/O behind a protocol): `WikiClient`, `WikipediaContentProvider`. | Models, Foundation, NaturalLanguage, os (logging). Adapters may also use ImageIO, CoreGraphics and CryptoKit (approved for W1, 2026-11-06). Never SwiftUI or UIKit. |
| 5 | Models | `Models/` | Plain value types (`struct`/`enum`), `Codable`, `Hashable`, `Sendable`. | Foundation only |
| 6 | Data | `Resources/`, `tools/` | Bundled generated data and the scripts that generate it. | n/a |

Today `PreferencesStore` lives in `Features/Picker/` and the open PR #4 adds `MetStore` in
`Features/Met/`. Both are app-wide stores and move to `Stores/` in one small follow-up PR after #4
merges. Don't move them inside unrelated PRs (it causes merge conflicts for everyone).

## Dependency rules

1. **Downwards only.** Models never reference Services. Services never reference SwiftUI, a view,
   a store or `UserDefaults`. Stores never reference views.
2. **Features don't import each other.** If two features need the same view, move it to
   `Features/Components/`. If they need the same state, it's a store. Navigation between features
   is wired in `App/RootView`.
3. **Concrete I/O is named only in `App/`.** `WikipediaContentProvider()`, `UserDefaults.standard`,
   `URLSession.shared` and `URLCache` are created in the composition root and passed in.
   Everything else takes a protocol (`SpeciesContentProvider`) or an injected value, with no
   default that silently reaches the network. Test code passes fakes.
4. **No new singletons.** No `static let shared` outside `App/`. Share one instance by creating it
   in `App/` and passing it through `init` or `.environment(...)`.
5. **Views are dumb.** A view reads state and calls intent methods (`model.toggleSaved()`), nothing
   more. No `async` fetching, filtering, sorting, licence checks or business rules in a `View`
   body or `.task`. Put them in the feature's view model or a service.
6. **Pure logic stays pure and tested.** Anything in `Services/` that decides *what* to show is a
   value type or `enum` with static functions, no I/O, and has unit tests. Change it, change its
   tests.
7. **No third-party dependencies** without a `Decided` entry in [decisions.md](decisions.md).

## The content pipeline is the only door for animal content

This is how the architecture enforces non-negotiable rules 2 to 5 in [AGENTS.md](../AGENTS.md)
(licences, attribution, zero AI content, real images).

```
open source (Wikipedia / Commons / Wikidata)
   → adapter (WikiClient, future catalog/static-JSON adapters)
   → ContentPolicy (licence allowlist, junk/AI/artwork filters)   ← enforced here, once
   → SpeciesContent / LicensedImage / Attribution (Models)
   → FeedComposer → FeedCard → views
```

- Every animal-related string or image a user sees must arrive through a `SpeciesContentProvider`
  (or the generated `taxonomy.json`) and pass `ContentPolicy`. **Never hard-code animal content in
  Swift**: no species names, group names, scientific names, facts, captions or statuses in a view
  or enum. UI chrome ("Did you know?", "Saved", button labels) is fine.
- Anything that shows media carries its `Attribution` in the model, so a view cannot render media
  without a credit.
- A new content source is a new adapter conforming to `SpeciesContentProvider` (or a new protocol
  for a new kind of data, for example a species catalog). It plugs in at `App/`. It never adds a
  second path around `ContentPolicy`. Update
  [content-and-licensing.md](content-and-licensing.md) and get human approval first.
- Stores keep **ids**, not copies of content. Persist `wikiTitle` and look the name up from the
  taxonomy or provider when showing it, so regenerating data (D-011) never leaves stale text on a
  device.

## Naming

| Kind | Pattern | Example |
| --- | --- | --- |
| Screen view | `<Thing>View` | `FeedView`, `SpeciesDetailView` |
| Screen state | `<Thing>ViewModel`, `@Observable @MainActor final class` | `FeedViewModel` |
| App-wide state | `<Thing>Store`, `@Observable final class`, in `Stores/` | `PreferencesStore`, `MetStore` |
| Role protocol | noun for the role | `SpeciesContentProvider` |
| Implementation of a role | `<Source><Role>` | `WikipediaContentProvider`, later `StaticJSONContentProvider` |
| Raw HTTP | `<Source>Client` | `WikiClient` |
| Pure logic | verb-noun `enum` or `struct` | `FeedComposer`, `SpeciesPicker`, `ContentPolicy` |
| Persisted key | `<name>.v<N>`; bump N on a breaking change | `preferences.v1`, `met.v1` |
| Tests | `<TypeUnderTest>Tests.swift` | `FeedComposerTests.swift` |

- One primary type per file, and the file is named after it. Small helpers used only by that type
  may sit in the same file as `private` types.
- Use the words the docs use (species, taxon, lineage, card, intro, fact, attribution). Don't
  invent synonyms (animal/creature/item) for the same thing in code.

## Concurrency and errors

- View models and stores that views observe are `@MainActor`. Caches shared across tasks are
  `actor`s. Models are `Sendable`.
- Long work runs in a `Task` owned by a view model, cancelled when it is replaced (see
  `FeedViewModel.generation`). No detached tasks.
- `try?` is allowed only where a missing value has a documented fallback (as in
  `WikipediaContentProvider`). Otherwise errors propagate to the view model, which turns them into
  a user-facing state.

## Size and shape limits

These are review triggers, not hard failures. Going over one means the design note must say why.

- A file over about **300 lines**, or a single view `body` over about **80 lines**: split it.
- A function over about **50 lines**, or more than three levels of nesting: split it.
- A `switch` over `FeedCard` (or any core enum) outside `FeedCard` itself, `FeedComposer` and the
  view that renders cards: add a computed property on the enum instead.
- Copy-pasted logic in two places: extract it before adding a third.
- Parallel dictionaries keyed by id that mirror another collection (for example position maps next
  to `cards`): put the data on the model instead.

## Where new work goes

| You are adding... | Put it in | Also |
| --- | --- | --- |
| A new screen or flow | `Features/<Name>/<Name>View.swift` (+ `<Name>ViewModel.swift` if it has logic) | Wire it in `App/RootView`. Update product.md. |
| A new card type | Case on `FeedCard` + payload struct in `Models/`, composition in `FeedComposer`, view in `Features/Feed/` | Tests in `FeedComposerTests`. Update data-model.md. |
| A new persisted preference or collection | Field on an existing store, or a new `Stores/<Thing>Store.swift` | New field gets a default; data-model.md lists the key. |
| A new content source | Adapter in `Services/` conforming to a role protocol, created in `App/` | content-and-licensing.md first, human approval. |
| A live species catalog | A `SpeciesCatalog` role protocol in `Services/`, a bundled-JSON implementation (today's `TaxonomyLoader`) and a remote one, chosen in `App/` | The feed and picker take the catalog, never a URL. |
| Likes that steer the feed | `Stores/LikesStore.swift` for persistence; `SpeciesPicker` takes likes as plain input (still pure) | Picker tests for the new weighting. |
| Species data changes | `tools/gen_taxonomy.py` (or the Wikidata importer), regenerate `taxonomy.json` | Same JSON shape, or update data-model.md and the decoder together. |
| Build or CI changes | `project.yml`, `.github/workflows/` | contributing.md. |

## The review gate

Decision D-014 (Maxwell Rhinelander, 2026-11-06). It applies to every agent and every person,
including collaborators' agents.

### 1. Design before code

Before writing code for anything bigger than a one-file fix, post a short design note and wait for
the architect's answer.

- **Where:** open a **draft PR** whose first commit adds `docs/designs/<yyyy-mm-dd>-<slug>.md`
  using the [design template](designs/TEMPLATE.md). Put "Design review" in the PR title. Agents
  in Maxwell's Claude project may also message the architect thread, but the note still goes in
  the repo so everyone can see it.
- **What:** the problem, which layer and folders it touches, new types and their responsibilities,
  how data flows, any new dependency, persisted key or content source, and the tests you will add.
  Half a page is usually enough.
- **Answer:** the architect replies on the draft PR with one of:
  - `Architecture review: Design approved` (start coding on the same branch),
  - `Architecture review: Changes requested` (with what to change), or
  - `Architecture review: Needs a human decision` (Maxwell decides; record it in decisions.md).

Small fixes (one file, no new type, no change in how layers talk) can skip the design note, but
still need sign-off on the PR.

### 2. Sign-off before merge

No PR merges to `main` without a review or comment on that PR that starts with
`Architecture review: Approved`, made on the PR's latest commit. A push after the sign-off needs a
new sign-off unless it only touches docs or fixes a review comment.

The architect checks the PR against this file: layers and dependency rules, the content pipeline,
naming, size limits, tests, and that the docs were updated (AGENTS.md "Keeping the docs current").

### Who the architect is

The architect is a Claude agent in Maxwell's project (thread "Guard app architecture as code
architect"). It watches the repo's PRs and answers on GitHub. Because every agent here posts
through the same GitHub account, the sign-off is the marker text above, not a GitHub approval.
The architect merges a PR once it has signed off and CI is green, choosing the merge order and
resolving doc conflicts (Maxwell approved this on 2026-11-06). Other agents never merge. Maxwell
can still merge by hand.

If a design or PR has had no architect answer for 24 hours, Maxwell can sign off directly with the
same marker text. Nobody else, human or agent, may write the marker on their own PR.
