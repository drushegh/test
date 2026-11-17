# Security Model: Roles, Teams, Impersonation, Verification

How Dataverse decides what a caller can see, and how to prove a security
design works. Role *deployment* commands live in solutions-alm.md.

## System Administrator proves nothing

System Administrator holds every privilege at Organization depth and also
sees secured columns, so **row-level security, business-unit scoping,
sharing and column security are invisible to an admin**. A confidentiality
or RBAC feature "verified" while signed in as the admin (or as the
service principal running your scripts) has not been verified.

- Test as a **non-admin persona** holding only the roles the real user
  will have. Keep one test user per persona.
- Scripted checks: run the read as that persona (impersonation, below) and
  assert both what it *can* and *cannot* see. A record visible to the
  admin and absent for the persona is the pass condition, not a bug.
- Support User and other built-in roles are read-heavy and unrepresentative;
  don't use them as stand-ins.
- Users without a licence (or disabled) don't behave like real users:
  their privileges can be filtered or the call refused. Licence test
  personas properly.

## Impersonation

| Surface | How | Notes |
|---|---|---|
| Web API | header `CallerObjectId: <Entra object id>` (preferred) or legacy `MSCRMCallerID: <systemuserid>` | the caller needs `prvActOnBehalfOfAnotherUser` (Delegate role), assigned **directly**, not via a team |
| SDK for .NET | `ServiceClient.CallerId = <systemuserid>` | same privilege rule |
| Plug-in | `factory.CreateOrganizationService(<id>)` | see below |

Effective privileges are the **intersection** of impersonator and
impersonated user. `createdonbehalfby` / `modifiedonbehalfby` record who
really made the call.

### Plug-ins run as the calling user by default

`CreateOrganizationService(context.UserId)` returns a service running as
the step's "Run in User's Context" user — **Calling User by default**, so
a plug-in is no more privileged than the person who triggered it. A
derived write the user can't make themselves (updating a parent they
can't see, reading platform tables) fails for real users and passes for
the admin who tested it.

- `CreateOrganizationService(null)` → the **SYSTEM** user (elevated). Use
  it deliberately for derived writes and platform reads, and keep the
  calling-user service for anything that should respect the user's rights.
- `context.InitiatingUserId` → the user who started the chain, regardless
  of step registration.
- Base classes that expose a "user service" (for example
  `PluginUserService` in the `pac plugin init` template) wrap
  `context.UserId` — not elevated (verify in your template version).
- Verify as the target persona, never as System Administrator.

## Team ownership

A team can't own records until it holds at least one security role
(`0x80042f0a` TeamNotAssignedRoles: "The team has not been assigned any
roles"). Assign the role before assigning records:

```http
POST [org]/api/data/v9.2/teams(<teamid>)/teamroles_association/$ref
{"@odata.id": "[org]/api/data/v9.2/roles(<roleid>)"}
```

Roles are business-unit scoped: use the role row belonging to the team's
business unit.

## Custom security roles need a platform baseline

A role holding only your tables' privileges produces an app that won't
open, empty sitemaps and "no privilege" errors on forms and views. Start
from (or copy) the **App Opener** role — or keep the role editor's
"Include App Opener privileges" option on — then add table rights.
Typical baseline privileges a hand-built role misses (verify against the
App Opener role in your environment):

- Customization: `prvReadEntity`, `prvReadAttribute`, `prvReadRelationship`,
  `prvReadQuery` (system views), `prvReadSystemForm`, `prvReadAppModule`,
  `prvReadWebResource`.
- Core records: `prvReadUserQuery` (saved views), user entity UI settings
  (create/read/write).
- Business management: `prvReadUser`.

Fresh roles may already carry some defaults; diff the role against App
Opener rather than assuming either way.

Granting privileges in code (`AddPrivilegesRole`): each privilege's depth
must be one the privilege supports (`CanBeBasic`, `CanBeLocal`,
`CanBeDeep`, `CanBeGlobal` on the `privilege` row). **One invalid depth
fails the whole call**, so clamp every depth to the supported set before
sending the batch.

## Checklist

- [ ] Every security claim tested as a non-admin persona, with a negative
      assertion (cannot see / cannot write)
- [ ] Plug-in writes that exceed the user's rights use an explicit
      elevated service, with a comment saying why
- [ ] Owner teams have a role before owning records
- [ ] Custom roles built from App Opener, depths clamped
