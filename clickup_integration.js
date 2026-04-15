// =====================================================
// Fluxgen × ClickUp Integration
// ─────────────────────────────────────────────────────
// HOW TO USE:
//   1. Open your Google Apps Script project
//   2. Click "+" next to Files → add new script file
//   3. Name it "clickup_integration"
//   4. Paste this entire file
//   5. Save
//   6. Run  setupClickUpOnce()  ONE TIME  ← creates list, fields, tasks
//   7. Run  syncAllHistoryToClickUp()  ONE TIME  ← imports all existing data
//   8. Done — live sync happens automatically on every status update
// =====================================================

var CU_TOKEN  = "pk_73221015_QWELL6Z136JTYFDHAMGFIWVGBCMX5OVH";
var CU_SPACE  = "90166794012";

// ─── ClickUp API helper ──────────────────────────────
function cuReq(method, path, body) {
  var opts = {
    method: method,
    headers: {
      "Authorization": CU_TOKEN,
      "Content-Type":  "application/json"
    },
    muteHttpExceptions: true
  };
  if (body) opts.payload = JSON.stringify(body);
  var res = UrlFetchApp.fetch("https://api.clickup.com/api/v2" + path, opts);
  try { return JSON.parse(res.getContentText()); } catch(e) { return {}; }
}

// ─── Script property store ───────────────────────────
function cuSet(key, val) { PropertiesService.getScriptProperties().setProperty(key, String(val)); }
function cuGet(key)       { return PropertiesService.getScriptProperties().getProperty(key) || ""; }

// =====================================================
// ▶ STEP 1 — Run ONCE: creates full ClickUp structure
// =====================================================
function setupClickUpOnce() {
  Logger.log("════ Setting up ClickUp ════");

  // ── 1. Create List ───────────────────────────────
  var listRes = cuReq("POST", "/space/" + CU_SPACE + "/list", {
    name: "Fluxgen Employee Status",
    content: "Auto-synced from Fluxgen Ops Portal",
    statuses: [
      { status: "Available",      color: "#95a5a6", type: "open"   },
      { status: "On Site",        color: "#e74c3c", type: "custom" },
      { status: "In Office",      color: "#27ae60", type: "custom" },
      { status: "Work From Home", color: "#3498db", type: "custom" },
      { status: "On Leave",       color: "#8e44ad", type: "custom" },
      { status: "Holiday",        color: "#9b59b6", type: "custom" },
      { status: "Weekend",        color: "#7f8c8d", type: "custom" },
      { status: "Closed",         color: "#2c5364", type: "closed" }
    ]
  });

  var listId = listRes.id;
  if (!listId) {
    Logger.log("ERROR creating list: " + JSON.stringify(listRes));
    return;
  }
  cuSet("CU_LIST_ID", listId);
  Logger.log("✅ List created → " + listId);

  // ── 2. Create Custom Fields ──────────────────────
  var fieldsToCreate = [
    { key: "SITE_NAME",        name: "Site Name",        type: "short_text", config: null },
    { key: "WORK_TYPE",        name: "Type of Work",     type: "drop_down",  config: { options: [{name:"Project"},{name:"Service"},{name:"Office Work"}] } },
    { key: "SCOPE",            name: "Scope of Work",    type: "text",       config: null },
    { key: "STATUS_DATE",      name: "Status Date",      type: "date",       config: null },
    { key: "WORK_DONE",        name: "Work Done",        type: "text",       config: null },
    { key: "COMPLETION",       name: "Completion %",     type: "number",     config: null },
    { key: "REMARKS",          name: "Remarks",          type: "short_text", config: null },
    { key: "NEXT_VISIT",       name: "Next Visit",       type: "drop_down",  config: { options: [{name:"No"},{name:"Yes"}] } },
    { key: "NEXT_VISIT_DATE",  name: "Next Visit Date",  type: "date",       config: null }
  ];

  fieldsToCreate.forEach(function(f) {
    var payload = { name: f.name, type: f.type };
    if (f.config) payload.type_config = f.config;
    var res = cuReq("POST", "/list/" + listId + "/field", payload);
    if (res.id) {
      cuSet("CU_FIELD_" + f.key, res.id);
      Logger.log("✅ Field: " + f.name + " → " + res.id);
    } else {
      Logger.log("⚠️  Field error (" + f.name + "): " + JSON.stringify(res));
    }
    Utilities.sleep(300);
  });

  // ── 3. Create one task per employee ─────────────
  Logger.log("Creating employee tasks...");
  _createEmployeeTasks(listId);

  Logger.log("════ Setup complete! List ID: " + listId + " ════");
  Logger.log("Now run  syncAllHistoryToClickUp()  to import existing data.");
}

// ─── Internal: create one task per employee ──────────
function _createEmployeeTasks(listId) {
  if (!listId) listId = cuGet("CU_LIST_ID");
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("Employees");
  if (!sheet) { Logger.log("No Employees sheet"); return; }

  var rows = sheet.getDataRange().getValues();
  for (var i = 1; i < rows.length; i++) {
    if (!rows[i][0]) continue;
    var empId   = String(rows[i][0]);
    var empName = String(rows[i][1]);
    var empRole = String(rows[i][2]);

    // Skip if task already exists
    if (cuGet("CU_TASK_" + empId)) {
      Logger.log("Skip (exists): " + empName);
      continue;
    }

    var res = cuReq("POST", "/list/" + listId + "/task", {
      name: empName,
      description: "Role: " + empRole + "\nEmp ID: " + empId,
      status: "Available"
    });

    if (res.id) {
      cuSet("CU_TASK_" + empId, res.id);
      Logger.log("✅ Task: " + empName + " → " + res.id);
    } else {
      Logger.log("⚠️  Task error (" + empName + "): " + JSON.stringify(res));
    }
    Utilities.sleep(400);
  }
}

// =====================================================
// ▶ STEP 2 — Run ONCE: imports all existing sheet data
// =====================================================
function syncAllHistoryToClickUp() {
  Logger.log("════ Syncing historical data ════");
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("StatusUpdates");
  if (!sheet) { Logger.log("No StatusUpdates sheet"); return; }

  var data = sheet.getDataRange().getValues();

  // Get latest row per employee (their current status)
  var latestByEmp = {};
  for (var i = 1; i < data.length; i++) {
    if (!data[i][1]) continue;
    var empId = String(data[i][1]);
    var date  = formatDate(data[i][8]);
    if (!latestByEmp[empId] || date > latestByEmp[empId].date) {
      latestByEmp[empId] = {
        empId:         empId,
        empName:       String(data[i][2]),
        siteName:      String(data[i][4] || ""),
        workType:      String(data[i][5] || ""),
        scope:         String(data[i][6] || ""),
        status:        String(data[i][7] || ""),
        date:          date,
        workDone:      String(data[i][9]  || ""),
        pct:           String(data[i][10] || "0"),
        remarks:       String(data[i][11] || ""),
        nextVisit:     String(data[i][12] || "No"),
        nextVisitDate: String(data[i][13] || "")
      };
    }
  }

  var count = 0;
  for (var id in latestByEmp) {
    var r = latestByEmp[id];
    pushStatusToClickUp(
      r.empId, r.empName, r.status, r.siteName, r.workType,
      r.scope, r.date, r.workDone, r.pct, r.remarks,
      r.nextVisit, r.nextVisitDate
    );
    count++;
    Utilities.sleep(500);
  }
  Logger.log("════ Synced " + count + " employees ════");
}

// =====================================================
// LIVE SYNC — called from doPost automatically
// =====================================================
function pushStatusToClickUp(empId, empName, status, siteName, workType, scope, date, workDone, pct, remarks, nextVisit, nextVisitDate) {
  try {
    var listId = cuGet("CU_LIST_ID");
    if (!listId) return; // ClickUp not set up yet

    // Get or create task for this employee
    var taskId = cuGet("CU_TASK_" + empId);
    if (!taskId) {
      var res = cuReq("POST", "/list/" + listId + "/task", {
        name:   empName,
        status: status || "Available"
      });
      if (!res.id) return;
      taskId = res.id;
      cuSet("CU_TASK_" + empId, taskId);
    }

    // ── Update task status ────────────────────────
    cuReq("PUT", "/task/" + taskId, { status: status || "Available" });

    // ── Update custom fields ──────────────────────
    var fSite = cuGet("CU_FIELD_SITE_NAME");
    var fWork = cuGet("CU_FIELD_WORK_TYPE");
    var fScope = cuGet("CU_FIELD_SCOPE");
    var fDate = cuGet("CU_FIELD_STATUS_DATE");
    var fWD   = cuGet("CU_FIELD_WORK_DONE");
    var fPct  = cuGet("CU_FIELD_COMPLETION");
    var fRem  = cuGet("CU_FIELD_REMARKS");
    var fNV   = cuGet("CU_FIELD_NEXT_VISIT");
    var fNVD  = cuGet("CU_FIELD_NEXT_VISIT_DATE");

    if (fSite)  _cuSetField(taskId, fSite,  siteName  || "");
    if (fWork)  _cuSetField(taskId, fWork,  workType  || "", "dropdown");
    if (fScope) _cuSetField(taskId, fScope, scope     || "");
    if (fDate && date)   _cuSetField(taskId, fDate, new Date(date).getTime(), "date");
    if (fWD)    _cuSetField(taskId, fWD,   workDone  || "");
    if (fPct)   _cuSetField(taskId, fPct,  parseInt(pct) || 0, "number");
    if (fRem)   _cuSetField(taskId, fRem,  remarks   || "");
    if (fNV)    _cuSetField(taskId, fNV,   nextVisit || "No", "dropdown");
    if (fNVD && nextVisitDate) _cuSetField(taskId, fNVD, new Date(nextVisitDate).getTime(), "date");

    // ── Add comment (history log) ─────────────────
    var lines = ["📅 *" + date + "* — Status updated"];
    if (status)   lines.push("• Status: *" + status + "*");
    if (siteName) lines.push("• Site: " + siteName);
    if (workType) lines.push("• Work Type: " + workType);
    if (scope)    lines.push("• Scope: " + scope);
    if (workDone) lines.push("• Work Done: " + workDone + " (" + (pct||0) + "%)");
    if (remarks)  lines.push("• Remarks: " + remarks);
    if (nextVisit === "Yes") lines.push("• Next Visit: " + (nextVisitDate || "TBD"));
    cuReq("POST", "/task/" + taskId + "/comment", { comment_text: lines.join("\n") });

  } catch(err) {
    Logger.log("ClickUp push error: " + err.toString());
  }
}

// ─── Set a ClickUp custom field value ────────────────
function _cuSetField(taskId, fieldId, value, type) {
  var payload = {};
  if (type === "dropdown") {
    payload = { value: String(value) };
  } else if (type === "date") {
    payload = { value: value }; // timestamp ms
  } else if (type === "number") {
    payload = { value: value };
  } else {
    payload = { value: String(value) };
  }
  cuReq("POST", "/task/" + taskId + "/field/" + fieldId, payload);
}
