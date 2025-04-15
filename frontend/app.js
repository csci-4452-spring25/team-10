const dummyTasks = ["Buy groceries", "Finish project", "Call Alice"];
const taskList = document.getElementById("taskList");
const addBtn = document.getElementById("addBtn");
const taskInput = document.getElementById("taskInput");

// Render dummy tasks on load
dummyTasks.forEach(task => renderTask(task));

addBtn.addEventListener("click", addTask);

function renderTask(taskText) {
  const li = document.createElement("li");
  li.innerHTML = `
    <span>${taskText}</span>
    <button class="delete-btn">Delete</button>
  `;
  const deleteBtn = li.querySelector(".delete-btn");
  deleteBtn.addEventListener("click", () => li.remove());
  taskList.appendChild(li);
}

function addTask() {
  const task = taskInput.value.trim();
  if (task) {
    renderTask(task);
    taskInput.value = "";
  }
}
