# Model-Driven Apps: Forms, Views, App Modules, Word Templates

Traps met when forms, views and apps are built or changed in code (form
XML, `savedquery`, `appmodule`) rather than in the designers. Form
*scripting* is in client-scripting.md.

## Forms built from code

- **Cell `id`s and tab/section `name`s behave as global keys.** A
  deterministic id generator reused across scripts, or a copied form XML
  with its ids left in place, makes two forms share ids; at publish the
  older form's stored labels get overwritten. Give every generator its own
  id range (or fresh GUIDs per cell) and namespace section/tab names
  (`contoso_project_summary`, not `summary`).
- **Replacing an out-of-box main form drops required fields.** A
  from-scratch form that omits a `SystemRequired`/`ApplicationRequired`
  column fails on save (for example the Case table's customer lookup:
  `0x80044410` "You should specify a parent contact or account"). Before
  publishing, diff the table's columns with `RequiredLevel` other than
  `None` against the form's `datafieldname` set; every required column
  must be on the form (hidden if need be) or set by logic.
- **Quick view forms are read-only and script-free**: no form scripts, no
  business rules, no custom controls, so they cannot hide empty fields.
  Memo columns render as large empty boxes and single-column sections lay
  out best. For a conditional summary, use several small quick views side
  by side on a host tab, a subgrid, or a form component control.
- After publishing, the Unified Interface client caches form definitions
  in IndexedDB. `indexedDB.deleteDatabase()` is a no-op while the app
  holds the database open; in browser automation clear the origin's
  storage instead (Chrome DevTools Protocol `Storage.clearDataForOrigin`)
  and reload, or a "failed" change may just be a stale cache.

## Views

Out-of-box tables ship system views with obvious names (Case has "All
Cases", "Active Cases" and more). A name-based "create if missing"
step silently skips the custom view because a view of that name already
exists. Prefix custom view names, or key idempotency on something you
own (a stored `savedqueryid`), and list existing views first.

## App modules

- Building an app through the Web API can leave it without its table
  components: `AddAppComponents` has rejected tables (component type 1)
  and `appmodulecomponent` can't be created directly (observed; verify).
  Admins still see data, so the gap shows up only for non-admin users,
  who get an empty app. Add tables in the app designer ("Add page →
  Dataverse table"), publish, then test as a non-admin.
- The app's users need a role carrying the platform baseline privileges
  (security-model.md), plus the app shared to that role.
- Copilot form-fill assistance (form fill assist toolbar, smart paste)
  is controlled by app settings, toggled per app in the app designer
  (Settings → Features) or by updating the setting definitions
  (`FormFileUploadEnabled`, `FormPredictSmartPasteEnabled`; other names
  have been seen, such as `FormFillBarUXEnabled` and `FormPredictEnabled` —
  verify). Clear the browser cache twice and reload before deciding the
  change didn't take.

## Word templates

- A template only reaches **relationships chosen when the template was
  downloaded, one hop from the primary table**, and at most 100 related
  rows per relationship. Fields further away must be copied onto the
  primary table.
- **Denormalised copies go stale.** A one-off script that fills them
  leaves every later record blank. Pair the copy with a keep-current
  mechanism (plug-in or flow on create/update of the source, or a
  calculated/formula column where the data type allows) before relying
  on the template.
- Templates are bound to the environment they were downloaded from;
  moving them between environments isn't supported. Rebuild or re-upload
  per environment.
- Rebuilding a template outside Word (content controls bound to the
  template's data, MERGEFIELD conversion): see the office-formats skill's
  open-tooling reference.
