// app.js (updated for production API endpoint)
const API_URL = "http://3.87.167.52:8080";

const boardContainer = document.getElementById("board");
let boardData = {};

const statusIcon = {
  "Not Started": "🟡",
  "In Progress": "🟠",
  "Complete": "🟢"
};

async function fetchBoard() {
  const res = await fetch(`${API_URL}/board`);
  boardData = await res.json();
  renderBoard(boardData);
}

async function createTask(column) {
  const title = document.getElementById(`task-title-${column}`).value.trim();
  const desc = document.getElementById(`task-desc-${column}`).value.trim();
  if (!title) return;

  await fetch(`${API_URL}/tasks`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title, description: desc, column, status: "Not Started" })
  });
  fetchBoard();
}

async function createColumn() {
  const input = document.getElementById("column-name");
  const name = input.value.trim();
  if (!name) {
    alert("Column name cannot be empty.");
    return;
  }

  const res = await fetch(`${API_URL}/columns`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name })
  });

  if (res.ok) {

    await fetch(`${API_URL}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: "(empty)",
        description: "",
        column: name,
        status: "Not Started"
      })
    });

    input.value = "";
    document.getElementById("new-column-popup").style.display = "none";
    document.getElementById("add-column-toggle").style.display = "inline-block";
    fetchBoard();
  } else {
    const data = await res.json();
    alert(data.error || "Failed to add column.");
  }
}

function showColumnInput() {
  document.getElementById("add-column-toggle").style.display = "none";
  document.getElementById("new-column-popup").style.display = "flex";
  document.getElementById("column-name").focus();
}

function resizeInput(input) {
  input.style.width = "auto";
  input.style.width = input.scrollWidth + "px";
}

function makeColumnTitleEditable(spanEl, oldName) {
  const input = document.createElement("input");
  input.type = "text";
  input.value = oldName;
  input.className = "edit-column-input";
  spanEl.replaceWith(input);
  input.focus();

  async function saveTitleChange() {
    const newName = input.value.trim();
    if (!newName || newName === oldName || boardData[newName]) {
      input.replaceWith(spanEl);
      return;
    }
  
    const tasksToMove = boardData[oldName] || [];
    for (const task of tasksToMove) {
      await fetch(`${API_URL}/tasks/move`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          id: task.task_id || task.id,
          from: oldName,
          to: newName,
          status: task.status
        })
      });
    }
  
    input.replaceWith(spanEl);
    fetchBoard();
  }
  

  input.addEventListener("blur", saveTitleChange);
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      input.blur();
    }
  });
}

async function deleteTask(id) {
  await fetch(`${API_URL}/tasks/${id}`, { method: "DELETE" });
  fetchBoard();
}

async function moveTask(id, from, to) {
  await fetch(`${API_URL}/tasks/move`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id, from, to })
  });
  
  const task = boardData[from]?.find(t => t.id === id);
  if (task) {
    boardData[from] = boardData[from].filter(t => t.id !== id);
    boardData[to] = boardData[to] || [];
    boardData[to].push({ ...task, column: to });
  }

  renderBoard(boardData);
}

function toggleStatusMenu(taskId) {
  document.querySelectorAll(".status-menu").forEach(menu => menu.style.display = "none");
  const menu = document.getElementById(`status-menu-${taskId}`);
  if (menu) menu.style.display = menu.style.display === "block" ? "none" : "block";
}

function renderBoard(data) {
  boardContainer.innerHTML = "";
  for (const column in data) {
    const colEl = document.createElement("div");
    colEl.className = "column";
    colEl.id = column;

    const columnHeader = document.createElement("div");
    columnHeader.className = "column-header";

    const spanTitle = document.createElement("span");
    spanTitle.textContent = column;
    spanTitle.style.cursor = "pointer";
    spanTitle.onclick = () => makeColumnTitleEditable(spanTitle, column);

    const taskBtn = document.createElement("button");
    taskBtn.className = "create-task-btn";
    taskBtn.textContent = "＋";
    taskBtn.onclick = () => showTaskInput(column);

    columnHeader.append(spanTitle, taskBtn);
    colEl.appendChild(columnHeader);

    const taskList = document.createElement("div");
    taskList.className = "task-list";
    taskList.id = `list-${column}`;
    colEl.appendChild(taskList);

    const inputPopup = document.createElement("div");
    inputPopup.className = "input-popup";
    inputPopup.id = `task-input-${column}`;
    inputPopup.innerHTML = `
      <input type="text" id="task-title-${column}" placeholder="Task title">
      <textarea id="task-desc-${column}" placeholder="Task description"></textarea>
      <button onclick="createTask('${column}')">Add</button>
    `;
    colEl.appendChild(inputPopup);

    data[column].forEach(task => {
      task.id = task.task_id || task.id;
      if (!task.status) task.status = "Not Started";

      const taskDiv = document.createElement("div");
      taskDiv.className = "task";
      taskDiv.dataset.id = task.id;
      taskDiv.dataset.column = column;

      taskDiv.innerHTML = `
        <div>
          <strong>${task.title}</strong>
          <small>${task.description}</small>
        </div>
        <div class="task-footer">
          <div class="task-status" onclick="toggleStatusMenu('${task.id}')">
            ${statusIcon[task.status] || statusIcon["Not Started"]}
            <div class="tooltip">${task.status}</div>
          </div>
          <div>
            <button class="task-menu-btn" onclick="deleteTask('${task.id}')">✖</button>
          </div>
        </div>
        <div class="status-menu" id="status-menu-${task.id}" style="display: none; margin-top: 5px;">
          <select onchange="changeStatus('${task.id}', '${column}', this.value)">
            ${["Not Started", "In Progress", "Complete"].map(status =>
              `<option value="${status}" ${status === task.status ? "selected" : ""}>${status}</option>`).join("")}
          </select>
        </div>
      `;
      taskList.appendChild(taskDiv);
    });

    boardContainer.appendChild(colEl);

    new Sortable(taskList, {
      group: "board",
      animation: 150,
      onEnd: async evt => {
        const id = evt.item.dataset.id;
        const from = evt.from.closest(".column").id;
        const to = evt.to.closest(".column").id;
        if (from !== to) await moveTask(id, from, to);
      }
    });
  }
}

async function changeStatus(id, column, newStatus) {
  const task = boardData[column].find(t => t.id === id);
  if (task) {
    task.status = newStatus;
    
    await fetch(`${API_URL}/tasks/move`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: task.task_id || task.id, from: column, to: column, status: newStatus })
    });

    renderBoard(boardData);
  }
}

function showTaskInput(column) {
  const input = document.getElementById(`task-input-${column}`);
  input.style.display = input.style.display === "block" ? "none" : "block";
}

document.addEventListener("DOMContentLoaded", fetchBoard);
