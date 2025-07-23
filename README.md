# RETROFIT
RETROFIT is a powershell script that allows for single, or bulk, upn &amp; mail attribute changes inside of the AD and forces the sync to the Entra Azura AD – Rename Email, Transform Records On‑prem Fast with an Interactive Tool.


### How to use

1. **Single user**
   *Run* → choose **S** → supply the current and desired email parts.
   Example:

   ```
   CURRENT email  : geoffrey.traugott@boom.aero
   New alias      : geoff.traugott
   ```

   The script converts that to `geoff.traugott@boom.aero`, renames the UPN (`‑UserPrincipalName`) and updates the **mail** attribute using `‑EmailAddress` — both parameters are native to `Set‑ADUser`. ([Microsoft Learn][1], [Microsoft Learn][1])

2. **Bulk**
   Create `rename.csv`:

   ```csv
   OldEmail,NewEmail
   geoffrey.traugott@boom.aero,geoff.traugott@boom.aero
   daniel.driver@boom.aero,daniel.doe@boom.aero
   ```

   Run the script, pick **C**, and provide the file path. The loop uses `Import‑Csv | ForEach‑Object` (a pattern endorsed in Microsoft examples) ([Microsoft Learn][4]) and in community tutorials ([Active Directory Pro][5]).

3. **Sync to Entra ID**
   When prompted, choose **Y** on the Azure AD Connect server (or over PS remoting).
   The `Start‑ADSyncSyncCycle -PolicyType Delta` command is Microsoft’s documented way to push changes immediately ([Microsoft Learn][3], [TECHCOMMUNITY.MICROSOFT.COM][6]) and is highlighted in PowerShell‑basics blog posts ([TECHCOMMUNITY.MICROSOFT.COM][7]).

---

## Why the script does two operations per user

* `‑UserPrincipalName $newEmail` sets the user’s **login name** (primary sign‑in). The parameter is directly supported by `Set‑ADUser` ([Microsoft Learn][1]).
* `‑EmailAddress $newEmail` updates the **mail** attribute so address books, GALs, and other systems stay in sync; Microsoft’s own example uses `-Replace @{mail="..."}` for the same goal ([Microsoft Learn][1], [Microsoft Learn][1]). Doing the changes separately avoids proxyAddress collisions.

---

## Tips & best practice

1. **Verify the UPN suffix exists first** (`Active Directory Domains & Trusts` ➜ “UPN Suffixes”) to avoid errors when assigning `@boom.aero` ([ALI TAJRAN][2]).
2. **Test on a few accounts**, then bulk‑run. The IT‑Koehler script pattern shows how to preview changes before committing (`‑WhatIf`) ([IT koehler blog][8]).
3. If you need to **reuse an old email** for another user, remove it from `proxyAddresses` after the sync (Exchange or Entra side) — otherwise Graph or AD will block duplicates, as documented in Set‑ADUser Q\&A threads ([Microsoft Learn][4]).
4. For very large batches, schedule the job off‑hours and consider an **Initial** rather than **Delta** sync if many attributes change.

Feel free to adapt the script (add `‑WhatIf`, write to a central log, wrap in Try/Catch, etc.). It provides a solid, interactive foundation to rename any on‑prem AD user — singly or in bulk — and keep Microsoft Entra ID perfectly in step.
