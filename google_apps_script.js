// =====================================================
// Google Apps Script - FULL SYNC VERSION
// =====================================================
// SETUP:
// 1. Your Google Sheet needs 2 sheet tabs:
//    - "StatusUpdates" (for status data)
//    - "Employees" (for employee list)
//
// 2. "Employees" sheet - Row 1 headers:
//    A1: EmpID | B1: Name | C1: Role
//
// 3. "StatusUpdates" sheet - Row 1 headers:
//    A1: Timestamp | B1: EmpID | C1: EmpName | D1: Role
//    E1: SiteName | F1: WorkType | G1: ScopeOfWork | H1: Status | I1: Date
//    J1: WorkDone | K1: CompletionPct | L1: WorkRemarks | M1: NextVisitRequired | N1: NextVisitDate
//
// 4. Extensions -> Apps Script -> paste this -> Deploy as Web App
//    Execute as: Me | Who has access: Anyone
// =====================================================

function formatDate(val) {
  if (!val) return "";
  if (val instanceof Date) {
    var y = val.getFullYear();
    var m = String(val.getMonth() + 1).padStart(2, "0");
    var d = String(val.getDate()).padStart(2, "0");
    return y + "-" + m + "-" + d;
  }
  var s = String(val);
  // If already in YYYY-MM-DD format
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  // Try to parse date string
  var parsed = new Date(s);
  if (!isNaN(parsed.getTime())) {
    var y = parsed.getFullYear();
    var m = String(parsed.getMonth() + 1).padStart(2, "0");
    var d = String(parsed.getDate()).padStart(2, "0");
    return y + "-" + m + "-" + d;
  }
  return s;
}

function doGet(e) {
  var action = e.parameter.action || "";
  var callback = e.parameter.callback || "";
  var result = {};

  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();

    if (action === "getUsers") {
      var sheet = ss.getSheetByName("Users");
      if (!sheet) {
        result = { status: "success", users: {} };
      } else {
        var data = sheet.getDataRange().getValues();
        var users = {};
        for (var i = 1; i < data.length; i++) {
          if (data[i][0]) {
            users[String(data[i][0])] = {
              password: String(data[i][1]),
              role: String(data[i][2]),
              displayName: String(data[i][3])
            };
          }
        }
        result = { status: "success", users: users };
      }
    }

    else if (action === "getEmployees") {
      var sheet = ss.getSheetByName("Employees");
      if (!sheet) {
        result = { status: "success", employees: [] };
      } else {
        var data = sheet.getDataRange().getValues();
        var emps = [];
        for (var i = 1; i < data.length; i++) {
          if (data[i][0]) {
            emps.push({ id: String(data[i][0]), name: String(data[i][1]), role: String(data[i][2]) });
          }
        }
        result = { status: "success", employees: emps };
      }
    }

    else if (action === "getStatus") {
      var dateFilter = e.parameter.date || "";
      var sheet = ss.getSheetByName("StatusUpdates");
      if (!sheet) {
        result = { status: "success", data: [] };
      } else {
        var data = sheet.getDataRange().getValues();
        var rows = [];
        for (var i = 1; i < data.length; i++) {
          var rowDate = formatDate(data[i][8]);
          if (dateFilter === "" || rowDate === dateFilter) {
            rows.push({
              empId: String(data[i][1]),
              empName: String(data[i][2]),
              role: String(data[i][3]),
              siteName: String(data[i][4]),
              workType: String(data[i][5]),
              scopeOfWork: String(data[i][6]),
              status: String(data[i][7]),
              date: rowDate,
              workDone: String(data[i][9] || ""),
              completionPct: String(data[i][10] || "0"),
              workRemarks: String(data[i][11] || ""),
              nextVisitRequired: String(data[i][12] || "No"),
              nextVisitDate: String(data[i][13] || "")
            });
          }
        }
        result = { status: "success", data: rows };
      }
    }

    else if (action === "getStatusRange") {
      var fromDate = e.parameter.from || "";
      var toDate = e.parameter.to || "";
      var empId = e.parameter.empId || "";
      var sheet = ss.getSheetByName("StatusUpdates");
      if (!sheet) {
        result = { status: "success", data: [] };
      } else {
        var data = sheet.getDataRange().getValues();
        var rows = [];
        for (var i = 1; i < data.length; i++) {
          var rowDate = formatDate(data[i][8]);
          var rowEmpId = String(data[i][1]);
          if (rowDate >= fromDate && rowDate <= toDate) {
            if (empId === "ALL" || empId === "" || rowEmpId === empId) {
              rows.push({
                empId: rowEmpId,
                empName: String(data[i][2]),
                role: String(data[i][3]),
                siteName: String(data[i][4]),
                workType: String(data[i][5]),
                scopeOfWork: String(data[i][6]),
                status: String(data[i][7]),
                date: rowDate,
                workDone: String(data[i][9] || ""),
                completionPct: String(data[i][10] || "0"),
                workRemarks: String(data[i][11] || ""),
                nextVisitRequired: String(data[i][12] || "No"),
                nextVisitDate: String(data[i][13] || "")
              });
            }
          }
        }
        result = { status: "success", data: rows };
      }
    }

    else if (action === "updateWorkDone") {
      var sheet = ss.getSheetByName("StatusUpdates");
      if (sheet) {
        var data = sheet.getDataRange().getValues();
        var targetEmpId = e.parameter.empId || "";
        var targetDate = e.parameter.date || "";
        for (var i = data.length - 1; i >= 1; i--) {
          if (String(data[i][1]) === targetEmpId && String(data[i][8]) === targetDate) {
            sheet.getRange(i + 1, 10).setValue(e.parameter.workDone || "");
            sheet.getRange(i + 1, 11).setValue(e.parameter.completionPct || "0");
            sheet.getRange(i + 1, 12).setValue(e.parameter.workRemarks || "");
            sheet.getRange(i + 1, 13).setValue(e.parameter.nextVisitRequired || "No");
            sheet.getRange(i + 1, 14).setValue(e.parameter.nextVisitDate || "");
            break;
          }
        }
      }
      result = { status: "success", message: "Work done updated." };
    }

    // ===== SERIAL NUMBERS =====
    else if (action === "getSerialNumbers") {
      var sheet = ss.getSheetByName("SerialNumbers");
      if (!sheet) {
        result = { status: "success", data: [] };
      } else {
        var data = sheet.getDataRange().getValues();
        var serials = [];
        for (var i = 1; i < data.length; i++) {
          if (data[i][0]) {
            serials.push({
              serialNo: String(data[i][0]),
              itemId: String(data[i][1]),
              itemName: String(data[i][2]),
              status: String(data[i][3] || "Available"),
              siteName: String(data[i][4] || ""),
              issuedTo: String(data[i][5] || ""),
              date: String(data[i][6] || "")
            });
          }
        }
        result = { status: "success", data: serials };
      }
    }

    // ===== INVENTORY =====
    else if (action === "getInventoryLog") {
      var sheet = ss.getSheetByName("InventoryLog");
      if (!sheet) {
        result = { status: "success", data: [] };
      } else {
        var data = sheet.getDataRange().getValues();
        var logs = [];
        for (var i = 1; i < data.length; i++) {
          if (data[i][0]) {
            logs.push({
              logId: String(data[i][0]),
              itemId: String(data[i][1]),
              itemName: String(data[i][2]),
              qty: String(data[i][3]),
              type: String(data[i][4]),
              siteName: String(data[i][5]),
              empName: String(data[i][6]),
              date: String(data[i][7]),
              remarks: String(data[i][8] || ""),
              purpose: String(data[i][9] || "")
            });
          }
        }
        // Reverse so newest first
        logs.reverse();
        result = { status: "success", data: logs };
      }
    }

    else if (action === "getInventory") {
      var sheet = ss.getSheetByName("Inventory");
      if (!sheet) {
        result = { status: "success", data: [] };
      } else {
        var data = sheet.getDataRange().getValues();
        var items = [];
        for (var i = 1; i < data.length; i++) {
          if (data[i][0]) {
            items.push({
              itemId: String(data[i][0]),
              name: String(data[i][1]),
              category: String(data[i][2]),
              qty: String(data[i][3]),
              minStock: String(data[i][4] || "5"),
              unit: String(data[i][5] || "pcs"),
              location: String(data[i][6] || ""),
              description: String(data[i][7] || ""),
              lastUpdated: String(data[i][8] || ""),
              updatedBy: String(data[i][9] || "")
            });
          }
        }
        result = { status: "success", data: items };
      }
    }

    else {
      result = { status: "success", message: "Fluxgen Operations API running." };
    }

  } catch (err) {
    result = { status: "error", message: err.toString() };
  }

  var output = JSON.stringify(result);
  if (callback) {
    return ContentService
      .createTextOutput(callback + "(" + output + ")")
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService
    .createTextOutput(output)
    .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var action = e.parameter.action || "submitStatus";

    if (action === "submitStatus") {
      var sheet = ss.getSheetByName("StatusUpdates");
      if (!sheet) {
        sheet = ss.insertSheet("StatusUpdates");
        sheet.appendRow(["Timestamp", "EmpID", "EmpName", "Role", "SiteName", "WorkType", "ScopeOfWork", "Status", "Date", "WorkDone", "CompletionPct", "WorkRemarks", "NextVisitRequired", "NextVisitDate"]);
      }
      var targetEmpId = e.parameter.empId || "";
      var targetDate = e.parameter.date || "";
      var data = sheet.getDataRange().getValues();
      var existingRow = -1;
      for (var i = data.length - 1; i >= 1; i--) {
        if (String(data[i][1]) === targetEmpId && formatDate(data[i][8]) === targetDate) {
          existingRow = i + 1;
          break;
        }
      }
      if (existingRow > 0) {
        sheet.getRange(existingRow, 1).setValue(new Date());
        sheet.getRange(existingRow, 5).setValue(e.parameter.siteName || "");
        sheet.getRange(existingRow, 6).setValue(e.parameter.workType || "");
        sheet.getRange(existingRow, 7).setValue(e.parameter.scopeOfWork || "");
        sheet.getRange(existingRow, 8).setValue(e.parameter.status || "");
      } else {
        sheet.appendRow([
          new Date(),
          targetEmpId,
          e.parameter.empName || "",
          e.parameter.role || "",
          e.parameter.siteName || "",
          e.parameter.workType || "",
          e.parameter.scopeOfWork || "",
          e.parameter.status || "",
          targetDate,
          "",
          "0",
          "",
          "No",
          ""
        ]);
      }
      // ── Push to ClickUp (live sync) ──
      try {
        pushStatusToClickUp(
          targetEmpId,
          e.parameter.empName || "",
          e.parameter.status  || "",
          e.parameter.siteName || "",
          e.parameter.workType || "",
          e.parameter.scopeOfWork || "",
          targetDate, "", "0", "", "No", ""
        );
      } catch(cuErr) { /* ClickUp sync non-blocking */ }
    }

    else if (action === "addEmployee") {
      var sheet = ss.getSheetByName("Employees");
      if (!sheet) {
        sheet = ss.insertSheet("Employees");
        sheet.appendRow(["EmpID", "Name", "Role"]);
      }
      sheet.appendRow([
        e.parameter.empId || "",
        e.parameter.empName || "",
        e.parameter.role || ""
      ]);
    }

    else if (action === "updateWorkDone") {
      var sheet = ss.getSheetByName("StatusUpdates");
      if (sheet) {
        var data = sheet.getDataRange().getValues();
        var targetEmpId = e.parameter.empId || "";
        var targetDate = e.parameter.date || "";
        var found = false;
        for (var i = data.length - 1; i >= 1; i--) {
          if (String(data[i][1]) === targetEmpId && String(data[i][8]) === targetDate) {
            // Update columns J-N (indices 10-14 in 1-based, 9-13 in 0-based)
            sheet.getRange(i + 1, 10).setValue(e.parameter.workDone || "");
            sheet.getRange(i + 1, 11).setValue(e.parameter.completionPct || "0");
            sheet.getRange(i + 1, 12).setValue(e.parameter.workRemarks || "");
            sheet.getRange(i + 1, 13).setValue(e.parameter.nextVisitRequired || "No");
            sheet.getRange(i + 1, 14).setValue(e.parameter.nextVisitDate || "");
            found = true;
            break;
          }
        }
        // If no matching row found, add headers if needed and note it
        if (!found) {
          // Could not find matching status entry to update
        } else {
          // ── Push Work Done update to ClickUp ──
          try {
            pushStatusToClickUp(
              targetEmpId, "", "", "", "", "",
              e.parameter.date || "",
              e.parameter.workDone || "",
              e.parameter.completionPct || "0",
              e.parameter.workRemarks || "",
              e.parameter.nextVisitRequired || "No",
              e.parameter.nextVisitDate || ""
            );
          } catch(cuErr) { /* ClickUp sync non-blocking */ }
        }
      }
    }

    else if (action === "addUser") {
      var sheet = ss.getSheetByName("Users");
      if (!sheet) {
        sheet = ss.insertSheet("Users");
        sheet.appendRow(["Username", "Password", "Role", "DisplayName"]);
      }
      // Check if user already exists, update if so
      var data = sheet.getDataRange().getValues();
      var targetUser = e.parameter.username || "";
      var found = false;
      for (var i = data.length - 1; i >= 1; i--) {
        if (String(data[i][0]) === targetUser) {
          sheet.getRange(i + 1, 2).setValue(e.parameter.password || "");
          sheet.getRange(i + 1, 3).setValue(e.parameter.role || "admin");
          sheet.getRange(i + 1, 4).setValue(e.parameter.displayName || "");
          found = true;
          break;
        }
      }
      if (!found) {
        sheet.appendRow([
          targetUser,
          e.parameter.password || "",
          e.parameter.role || "admin",
          e.parameter.displayName || ""
        ]);
      }
    }

    else if (action === "deleteUser") {
      var sheet = ss.getSheetByName("Users");
      if (sheet) {
        var data = sheet.getDataRange().getValues();
        var targetUser = e.parameter.username || "";
        for (var i = data.length - 1; i >= 1; i--) {
          if (String(data[i][0]) === targetUser) {
            sheet.deleteRow(i + 1);
            break;
          }
        }
      }
    }

    else if (action === "editEmployee") {
      var sheet = ss.getSheetByName("Employees");
      if (sheet) {
        var data = sheet.getDataRange().getValues();
        var targetId = e.parameter.empId || "";
        for (var i = data.length - 1; i >= 1; i--) {
          if (String(data[i][0]) === targetId) {
            sheet.getRange(i + 1, 2).setValue(e.parameter.empName || "");
            sheet.getRange(i + 1, 3).setValue(e.parameter.role || "");
            break;
          }
        }
      }
    }

    else if (action === "deleteEmployee") {
      var sheet = ss.getSheetByName("Employees");
      if (sheet) {
        var data = sheet.getDataRange().getValues();
        var targetId = e.parameter.empId || "";
        for (var i = data.length - 1; i >= 1; i--) {
          if (String(data[i][0]) === targetId) {
            sheet.deleteRow(i + 1);
            break;
          }
        }
      }
    }

    // ===== SERIAL NUMBERS =====
    else if (action === "addSerialNumber") {
      var sheet = ss.getSheetByName("SerialNumbers");
      if (!sheet) {
        sheet = ss.insertSheet("SerialNumbers");
        sheet.appendRow(["SerialNo", "ItemID", "ItemName", "Status", "SiteName", "IssuedTo", "Date"]);
      }
      sheet.appendRow([
        e.parameter.serialNo || "",
        e.parameter.itemId || "",
        e.parameter.itemName || "",
        e.parameter.status || "Available",
        "",
        "",
        new Date().toLocaleString()
      ]);
    }

    else if (action === "updateSerialStatus") {
      var sheet = ss.getSheetByName("SerialNumbers");
      if (sheet) {
        var data = sheet.getDataRange().getValues();
        var targetSN = e.parameter.serialNo || "";
        for (var i = data.length - 1; i >= 1; i--) {
          if (String(data[i][0]) === targetSN) {
            sheet.getRange(i + 1, 4).setValue(e.parameter.status || "Available");
            sheet.getRange(i + 1, 5).setValue(e.parameter.siteName || "");
            sheet.getRange(i + 1, 6).setValue(e.parameter.issuedTo || "");
            sheet.getRange(i + 1, 7).setValue(new Date().toLocaleString());
            break;
          }
        }
      }
    }

    // ===== INVENTORY CRUD =====
    else if (action === "addInventory") {
      var sheet = ss.getSheetByName("Inventory");
      if (!sheet) {
        sheet = ss.insertSheet("Inventory");
        sheet.appendRow(["ItemID", "Name", "Category", "Qty", "MinStock", "Unit", "Location", "Description", "LastUpdated", "UpdatedBy"]);
      }
      sheet.appendRow([
        e.parameter.itemId || ("INV-" + Date.now()),
        e.parameter.name || "",
        e.parameter.category || "",
        e.parameter.qty || "0",
        e.parameter.minStock || "5",
        e.parameter.unit || "pcs",
        e.parameter.location || "",
        e.parameter.description || "",
        new Date().toLocaleString(),
        e.parameter.updatedBy || ""
      ]);
    }

    else if (action === "editInventory") {
      var sheet = ss.getSheetByName("Inventory");
      if (sheet) {
        var data = sheet.getDataRange().getValues();
        var targetId = e.parameter.itemId || "";
        for (var i = data.length - 1; i >= 1; i--) {
          if (String(data[i][0]) === targetId) {
            sheet.getRange(i + 1, 2).setValue(e.parameter.name || "");
            sheet.getRange(i + 1, 3).setValue(e.parameter.category || "");
            sheet.getRange(i + 1, 4).setValue(e.parameter.qty || "0");
            sheet.getRange(i + 1, 5).setValue(e.parameter.minStock || "5");
            sheet.getRange(i + 1, 6).setValue(e.parameter.unit || "pcs");
            sheet.getRange(i + 1, 7).setValue(e.parameter.location || "");
            sheet.getRange(i + 1, 8).setValue(e.parameter.description || "");
            sheet.getRange(i + 1, 9).setValue(new Date().toLocaleString());
            sheet.getRange(i + 1, 10).setValue(e.parameter.updatedBy || "");
            break;
          }
        }
      }
    }

    else if (action === "invTransaction") {
      // Log the transaction
      var logSheet = ss.getSheetByName("InventoryLog");
      if (!logSheet) {
        logSheet = ss.insertSheet("InventoryLog");
        logSheet.appendRow(["LogID", "ItemID", "ItemName", "Qty", "Type", "SiteName", "EmpName", "Date", "Remarks", "Purpose"]);
      }
      logSheet.appendRow([
        "LOG-" + Date.now(),
        e.parameter.itemId || "",
        e.parameter.itemName || "",
        e.parameter.qty || "0",
        e.parameter.type || "Issue",
        e.parameter.siteName || "",
        e.parameter.empName || "",
        new Date().toLocaleString(),
        e.parameter.remarks || "",
        e.parameter.purpose || ""
      ]);

      // Update inventory quantity
      var invSheet = ss.getSheetByName("Inventory");
      if (invSheet) {
        var data = invSheet.getDataRange().getValues();
        var targetId = e.parameter.itemId || "";
        var txQty = parseInt(e.parameter.qty) || 0;
        var isIssue = (e.parameter.type || "Issue") === "Issue";
        for (var i = data.length - 1; i >= 1; i--) {
          if (String(data[i][0]) === targetId) {
            var currentQty = parseInt(data[i][3]) || 0;
            var newQty = isIssue ? (currentQty - txQty) : (currentQty + txQty);
            if (newQty < 0) newQty = 0;
            invSheet.getRange(i + 1, 4).setValue(newQty);
            invSheet.getRange(i + 1, 9).setValue(new Date().toLocaleString());
            invSheet.getRange(i + 1, 10).setValue(e.parameter.updatedBy || "");
            break;
          }
        }
      }
    }

    else if (action === "deleteInventory") {
      var sheet = ss.getSheetByName("Inventory");
      if (sheet) {
        var data = sheet.getDataRange().getValues();
        var targetId = e.parameter.itemId || "";
        for (var i = data.length - 1; i >= 1; i--) {
          if (String(data[i][0]) === targetId) {
            sheet.deleteRow(i + 1);
            break;
          }
        }
      }
    }

    return ContentService
      .createTextOutput(JSON.stringify({ status: "success" }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService
      .createTextOutput(JSON.stringify({ status: "error", message: error.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
