# OJ Float Design System

## 1. Product Intent

OJ Float is a calm Windows desktop command center for competitive programming practice. It should feel local, quick, and trustworthy, like a small instrument panel that is always within reach. The signature is compact density with soft rounded surfaces: high value numbers, quiet CJK labels, and stable cards that make daily progress easy to scan without changing any app behavior.

This contract describes the current visual system and the guardrails for the visual only refactor. It is the source of truth before future UI work under `lib/ui/**`.

## 2. Non Functional Change Guardrails

Future visual work may change presentation only. It must not change business behavior or user flows.

Required constraints:

* No changes to API requests, provider behavior, provider parsing, storage schemas, backup/import/export semantics, sync payloads, model structures, controller business rules, or app display mode flow.
* No runtime dependency changes unless explicitly approved.
* No Dart source changes during T1. Later visual tasks may edit UI only files named by the plan.
* Preserve all existing widget keys, including keys used by `test/widget_test.dart` and `test/startup_settings_test.dart`.
* Preserve callback wiring and disabled state contracts. Examples include refresh, settings, compact mode, open dashboard, import, export, save, delete, parse link, open problem, teammate refresh, module sorting, and tray/window callbacks.
* Preserve platform integration boundaries in `OjFloatHome`, `WindowShellService`, `tray_manager`, and `window_manager`.
* Preserve `AppPalette`, `buildAppTheme`, `AppSurfaceCard`, `AppEmptyState`, `Pill`, Material 3, and the Microsoft YaHei UI plus Segoe UI fallback stack as the design base.
* Do not invent a new app architecture, state management system, data model, sync flow, or navigation flow.
* If a visual improvement needs a new token or primitive, update this file before code uses it.

## 3. Color

Color comes from `AppPalette` in `lib/ui/app_theme.dart`. The live theme is selected through `AppColorTheme` and applied by `buildAppTheme`. Do not add raw colors in UI code unless the token is first added here and then represented in `AppPalette`.

### Semantic Roles

| Role | Current token | Usage |
| --- | --- | --- |
| App surface | `appSurfaceColor` | Window background and feature page background. |
| Card surface | `cardColor` | Primary cards, dashboard nav, dialogs, panels, list rows. |
| Muted card surface | `cardMutedColor` | Nested stat tiles, detail sections, pills, chip backgrounds. |
| Border | `borderColor` | Card borders, input borders, dashboard nav divider, chip outlines. |
| Text primary | `textPrimaryColor` | Titles, totals, card values, active nav text. |
| Text secondary | `textSecondaryColor` | Labels, hints, metadata, inactive nav text, empty copy. |
| Accent | `accentColor` | Primary actions, selected nav, progress, success tone, focused input border. |
| Danger | `dangerColor` | Errors, destructive tone, failed fetches, warning cards. |
| Compact surface | `compactSurfaceColor` | Small floating widget body. |
| Compact label | `compactLabelColor` | Small floating widget labels. |
| Compact text | `compactTextColor` | Small floating widget main number. |
| Compact shadow | `compactShadowColor` | Small floating widget elevation shadow. |
| Heatmap levels | `heatmapLevelColors` | Activity cells from empty to strongest activity. |

### Palettes

| Theme | Surface | Card | Muted | Border | Primary text | Secondary text | Accent | Danger |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Classic | `#F6F7F4` | `#FFFFFF` | `#F4F6F3` | `#E1E4DE` | `#17211D` | `#64706A` | `#2F6F4E` | `#B3261E` |
| Ocean | `#F2F8FA` | `#FFFFFF` | `#EAF4F7` | `#D3E4E8` | `#10242B` | `#5E7077` | `#197B8A` | `#C43D4B` |
| Rose | `#FBF5F7` | `#FFFFFF` | `#F8ECEF` | `#EBD5DB` | `#2A1B20` | `#75656A` | `#A33F62` | `#B3261E` |
| Dark | `#101418` | `#181D22` | `#20262C` | `#313A42` | `#F0F5F2` | `#A7B2AD` | `#77C69A` | `#FF8A80` |
| Candy | `#FFF7FB` | `#FFFFFF` | `#FFECF3` | `#F4C8D6` | `#23323A` | `#69767D` | `#31A9D8` | `#C23B61` |

### Color Rules

* Accent is for action, selection, focus, active progress, and positive state. Avoid accent as decoration on static content.
* Danger is for errors, failure, destructive action, and urgent warning. Do not use it for ordinary pending or neutral states.
* Muted surfaces should sit inside cards, not replace the app background.
* Heatmap colors are a data scale. Do not use them for ordinary status chips.
* Status colors that are not yet tokenized, such as blue grey fallback info and orange blocked refresh, must be either documented here before refactor or folded into semantic tokens during T2.

## 4. Typography

The app uses Material 3 with a CJK first font stack:

| Role | Font |
| --- | --- |
| Primary | `Microsoft YaHei UI` |
| Fallback 1 | `Segoe UI Variable Text` |
| Fallback 2 | `Segoe UI` |
| Fallback 3 | `Microsoft YaHei` |
| Fallback 4 | `SimSun` |
| Fallback 5 | `Arial` |

### Type Scale

| Level | Size | Weight | Usage |
| --- | --- | --- | --- |
| Compact total | 52 | 900 | Main number in compact widget. |
| Hero metric | 42 | 800 to 900 | Total solved and dashboard progress values. |
| Page title | 22 | 800 to 900 | Feature page and dashboard section headings. |
| Section title | 16 | 800 to 900 | Card group headings and list card titles. |
| Body | Material body medium | 400 to 600 | Main descriptions and form copy. |
| Label | 12 to 14 | 700 to 800 | Metadata, pills, account lines, hints. |
| Micro label | 11 to 12 | 400 to 700 | Dense stat labels and timestamp copy. |

### Typography Rules

* CJK readability wins over density. Body text must not drop below 12 in dense cards, and ordinary body copy should stay at Material body medium when space allows.
* Use `maxLines` and `TextOverflow.ellipsis` for usernames, problem titles, URLs, tags, module labels, and nav labels in compact spaces.
* Use heavy weights only for hierarchy anchors: totals, page titles, selected nav, card titles, and chip values.
* Do not replace the font stack with Inter or a web first font. This is a Windows desktop CJK product.

## 5. Spacing, Shape, and Surface

The current rhythm is a compact 4 point system expressed through Flutter `EdgeInsets` and `SizedBox` values.

| Token | Value | Current usage |
| --- | --- | --- |
| `space-1` | 3 to 4 | Tight text gaps, compact total label gap. |
| `space-2` | 6 to 8 | Icon to label gaps, chip gaps, list row gaps. |
| `space-3` | 10 to 12 | Form controls, nav button padding, card groups. |
| `space-4` | 14 to 16 | Default card padding, page side padding, feature list padding. |
| `space-5` | 18 | Large cards and compact widget vertical rhythm. |
| `space-6` | 24 | Compact widget side padding and larger separation. |

### Shape Tokens

| Token | Value | Usage |
| --- | --- | --- |
| `radius-control` | 8 | Inputs, buttons, cards, nav rows, nested stat tiles. |
| `radius-compact` | 20 | Compact floating widget. |
| `radius-pill` | 999 | Pills, chips, progress bars. |

### Surface Strategy

Use a mixed surface strategy:

* Primary separation comes from card fill plus a 1 px `borderColor` outline.
* Compact mode uses shadow, rounded corners, and translucent compact surface to read as a floating desktop widget.
* Nested content uses muted tonal shifts, usually `cardMutedColor`, instead of heavy shadows.
* Dialogs use Material 3 `AlertDialog` on `cardColor` with compact content width.

## 6. Component Primitives

Each primitive below is current product language, not a new architecture. Future work should polish these primitives without changing keys or callbacks.

### App Shell and Window Header

Structure: `OjFloatHome` owns display modes and wraps content in `Theme(data: buildAppTheme(...))`. `WindowHeader` is a 58 high draggable header with title, refresh, settings, compact, minimize, and exit actions.

Rules:

* Keep header height stable unless window minimum sizes are updated and tested.
* Preserve drag behavior through `onStartDrag` and preserve platform callbacks.
* Preserve `compact-mode-button` and `dashboard-exit-button` keys.
* Refresh action shows a 18 square progress indicator while refreshing and disables the callback.
* Header background uses the current Material surface from `Theme.of(context).colorScheme.surface`.

### Compact Widget

Structure: keyed `compact-widget`, rounded 340 by 154 default surface with total solved, refresh spinner, and today delta. It supports drag and tap.

Rules:

* Keep the visual hierarchy: label, 52 point total, today delta.
* Preserve `onPanStart` window dragging and `onTap` open behavior.
* Keep content readable at 300 by 132 minimum. The total may ellipsize but should not clip.
* Use compact palette tokens only for compact widget text, surface, and shadow.

### Large Float Module Entry

Structure: large float shows `WindowHeader`, `open-dashboard-button`, and a scrolling `large-float-modules` list. Entries are the same panels used by dashboard modules.

Rules:

* Preserve module order, enabled module behavior, and empty module message.
* Preserve keys for entry buttons: `heatmap-entry-button`, `problems-entry-button`, `refresh-logs-entry-button`, `teammates-entry-button`, `export-data-button`, and `import-backup-button`.
* Cards should remain dense enough for 380 by 540, with 16 side padding and 12 vertical gaps.

### Dashboard Navigation

Structure: `dashboard-shell` uses a 174 wide left nav keyed `dashboard-nav`, with one `_DashboardNavButton` per section.

Rules:

* Selected nav uses accent at 12 percent alpha, accent icon, and stronger text weight.
* Inactive nav uses transparent background and secondary text.
* Preserve `dashboard-nav-${section.name}` keys and section labels.
* Content starts at 18 horizontal padding and 14 top padding.

### Surface Card

Structure: `AppSurfaceCard` wraps card content with 14 default padding, `cardColor`, 8 radius, and `borderColor`. Optional `onTap` adds transparent `Material` and `InkWell`.

Rules:

* Use for reusable cards that may be tapped or appear in summary/action grids.
* Hover, pressed, and focus must come from Material ink and button themes, not custom gesture behavior that hides semantics.
* Default cards without actions must not look disabled.

### Empty State

Structure: `AppEmptyState` is an `AppSurfaceCard` with accent icon, bold title, secondary message, and optional action.

Rules:

* Empty states must explain the next useful action, not only say data is missing.
* Preserve feature page empty copy unless a visual task explicitly updates wording.
* Keep icon size near 24 and text readable in constrained windows.

### Metric and Stat Card

Structure: progress cards, summary tiles, heatmap stats, ranking cards, and status tiles combine a label, value, optional icon, and muted description.

Rules:

* Values use primary text or semantic status color. Labels use secondary text.
* Wide layouts may use 4 columns at 520 to 620 plus. Narrow layouts fall back to 2 columns or 1 column based on current code.
* Metric values must not wrap into unreadable lines. Use ellipsis or narrower type before changing data.

### Filters and Search Controls

Structure: Material 3 `TextField`, `TextFormField`, `DropdownButtonFormField`, `FilterChip`, `ActionChip`, `CheckboxListTile`, and `SwitchListTile` styled by `buildAppTheme`.

Rules:

* Inputs use filled `cardColor`, 8 radius, 12 by 10 content padding, `borderColor`, and accent focused border at 1.3 width.
* Preserve keys such as `problem-search-field`, `problem-status-filter`, `problem-platform-filter`, `clear-tag-filter-chip`, `color-theme-field`, and dashboard settings keys.
* Filter rows should use 8 point horizontal gaps and wrap tag chips with 6 point spacing.
* Focus state must be visible on keyboard navigation.

### Dialogs

Structure: `AlertDialog` for settings, problem details, problem editor, contest editor, teammate editor, heatmap detail, and import confirmation.

Rules:

* Dialog background uses `cardColor` through `dialogTheme`.
* Keep widths near existing contracts: settings 460, problem details 540, and editor widths defined by current dialogs.
* Preserve dialog keys and save button keys, including `problem-editor-dialog`, `save-problem-button`, `teammate-editor-dialog`, and `save-teammate-button`.
* Dialog actions use `TextButton` for cancel or secondary actions and `FilledButton` for commit.

### Pills and Status Chips

Structure: `Pill` uses horizontal 8, vertical 3, `cardMutedColor`, `borderColor`, 999 radius, 12 point bold label. Feature status chips may tint semantic colors at about 10 percent alpha.

Rules:

* Use `Pill` for neutral metadata: dates, tags, sync labels, platform labels.
* Use tinted status chips for success, warning, error, selected status, and teammate delta.
* Do not use emoji as icons. Use Material icons already in the app.

### Problem, Contest, Teammate, and Log Cards

Structure: feature cards use `cardColor`, `borderColor`, 8 radius, 12 to 14 padding, title row, metadata row, status chip or actions, and dense body copy.

Rules:

* Problem cards keep title, platform/date metadata, preview, tag strip, status menu, and compact actions with current keys.
* Contest cards keep summary stats, rank chart, empty state, and editable list behavior.
* Teammate cards keep nickname, account list, refresh timestamp, error pills, delta chip, ranking progress bars, and action keys.
* Refresh log cards keep status color mapping, timestamp/source metadata, count text, and message.
* Destructive actions must remain visually distinct and must not move to a pattern that increases accidental taps.

## 7. Interaction States

All interactive primitives must define these states before implementation.

| State | Contract |
| --- | --- |
| Default | Uses theme token colors, clear label hierarchy, no accidental accent decoration. |
| Hover | Material ink or button hover communicates clickability without layout shift. |
| Focus | Keyboard focus is visible through Material focus treatment or accent border. |
| Pressed | Ink ripple or pressed overlay appears inside the same radius. No size jump. |
| Selected | Accent tint at about 10 to 14 percent plus stronger icon/text treatment. |
| Disabled | Callback is null, Material disabled style applies, content remains legible. |
| Loading | Replace action icon or reserved area with a small progress indicator. Do not reflow key content. |
| Empty | Show calm secondary copy and, where useful, one clear next action. |
| Error | Use `dangerColor`, concise failure copy, and preserve prior usable data where the app already does so. |
| Warning | Use danger or a future warning token only for blocked, risky, or pending attention states. |
| Success | Use `accentColor` for successful refresh, positive delta, active sync, and completed statuses. |

Motion rules:

* Keep motion minimal and meaningful. Current app mostly relies on Material state feedback.
* Do not animate layout properties in future visual work.
* If adding transitions later, use short Material aligned durations, keep content stable, and respect platform reduced motion settings where available.

## 8. Responsive and Window Rules

The production target is Windows desktop. Browser and constrained screenshots are verification aids only when the Flutter web target runs.

| Surface | Target | Minimum | Rules |
| --- | --- | --- | --- |
| Compact | 340 by 154 | 300 by 132 | One screen, no scroll, total remains dominant, no clipped CJK. |
| Large float | 380 by 540 | 330 by 440 | Header plus dashboard button plus scrollable modules. Entries must remain tappable. |
| Dashboard | 960 by 680 | 760 by 520 | Left nav 174 wide, content scrolls, feature pages fit with readable controls. |
| Heatmap | 560 by 560 | 440 by 420 | Stats wrap, grid card remains visible and scrollable if constrained. |
| Feature pages | 760 by 620 | Use dashboard minimum when embedded | Header controls, filters, list cards, dialogs, and empty states remain readable. |
| Browser screenshots | Desktop and mobile/constrained where target works | Document fallback if blocked | Use web only as QA aid, not as the product source of truth. |

Layout rules:

* Wide summary status grid uses 4 columns at 620 plus. Narrow uses 2 columns.
* Wide action grid uses 3 columns at 620 plus. Narrow uses 1 column.
* Problem cards use 2 columns at 680 plus and 1 column below that.
* Contest stat summaries use 4 columns at 520 plus and 2 columns below that.
* Text overflow must use ellipsis for dense rows before any behavior or data change is considered.

## 9. Accessibility and CJK Rules

* Keep Chinese labels as first class content. Verify CJK clipping in compact, large float, dashboard nav, dialogs, chips, and feature card titles.
* Tooltips are required for icon only actions, matching current header and feature action patterns.
* Preserve keyboard reachability for form fields, buttons, chips, menus, and dialog actions.
* Maintain visible focus for inputs, dropdowns, buttons, chips, and popup menus.
* Body text should meet contrast against `appSurfaceColor`, `cardColor`, and `cardMutedColor` in every `AppColorTheme`.
* Do not use color alone for critical meaning when a label already exists. Status pills need text labels.
* Tap targets may be compact for desktop, but icon only controls need clear tooltips and stable hit boxes.

## 10. Visual QA Matrix

Final visual QA for the visual refactor must capture fresh evidence after implementation.

Required matrix:

| Surface | Desktop target | Constrained or mobile target | Notes |
| --- | --- | --- | --- |
| Compact widget | Windows 340 by 154 | Windows 300 by 132 | Capture default and refreshing if possible. |
| Large float | Windows 380 by 540 | Windows 330 by 440 | Capture module list, empty modules if reachable, dashboard entry. |
| Dashboard summary | Windows 960 by 680 | Windows 760 by 520 | Capture nav, progress card, status grid, action grid. |
| Heatmap | Windows 560 by 560 | Windows 440 by 420 | Capture stats and grid card. |
| Problems | Dashboard desktop | Dashboard constrained | Capture search, filters, tags, empty and populated card states where possible. |
| Refresh logs | Dashboard desktop | Dashboard constrained | Capture success, fallback, blocked, and failure if data exists. |
| Contests | Dashboard desktop | Dashboard constrained | Capture summary stats, chart card, empty and populated list where possible. |
| Teammates | Dashboard desktop | Dashboard constrained | Capture teammate card, ranking card, empty state where possible. |
| Settings and editors | Windows dialog capture | Constrained dialog capture | Capture settings, problem editor, teammate editor if reachable without changing data. |
| Browser web attempt | Desktop browser | Mobile or constrained browser | Try only if Flutter web target runs. If desktop imports or plugins block it, document the blocker and use Windows screenshots as fallback. |

Evidence rules:

* Store QA artifacts under `.omo/evidence/flutter-visual-only-refactor/` during final verification tasks.
* Screenshots must show the real app, not mocked static pictures, unless a test harness is clearly labeled as such.
* Any failed web target attempt must record the command, error, and fallback screenshots.

## 11. Open Consolidation Notes

These notes are not permission to change behavior. They guide later visual only tasks.

* `AppSurfaceCard` should be the preferred shared card primitive for surfaces used more than once.
* Some cards still use hand written `Container` decorations that match `AppSurfaceCard`; T2 to T4 may consolidate styling only if keys, callbacks, structure, and behavior stay intact.
* Blue grey info and orange blocked refresh colors are current ad hoc status colors. Future token work should decide whether to codify them or map them to existing semantic roles.
* The app is desktop first. Any web or mobile constrained pass is QA coverage, not a redesign target.
