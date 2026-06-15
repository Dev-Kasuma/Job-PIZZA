// ==================== TABLETTE PREMIUM 2026 - JAVASCRIPT ES6+ ====================

class PizzaTablet {
  constructor() {
    this.playerData = {
      name: '',
      job: '',
      grade: 0,
      deliveries: 0,
      earnings: 0,
      reputation: 0,
      level: 1
    };
    this.currentPage = 'home';
    this.orders = [];
    this.employees = [];
    this.societyData = {
      balance: 0,
      transactions: []
    };
    
    this.init();
  }

  init() {
    this.setupEventListeners();
    this.setupMenuNavigation();
    this.startClock();
    this.loadInitialData();
  }

  setupEventListeners() {
    // Close button
    document.getElementById("closeBtn").addEventListener("click", function () {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({})
    });
});
    
    // Quick action buttons
    document.getElementById('startDeliveryBtn')?.addEventListener('click', () => this.startDelivery());

    // Society buttons
    document.getElementById('depositBtn')?.addEventListener('click', () => this.openDepositModal());
    document.getElementById('withdrawBtn')?.addEventListener('click', () => this.openWithdrawModal());
    
    // NUI messages
    window.addEventListener('message', (event) => this.handleNuiMessage(event.data));
  }

  setupMenuNavigation() {
    const menuItems = document.querySelectorAll('.menu-item');
    console.log('Menu items found:', menuItems.length);
    menuItems.forEach(item => {
      item.addEventListener('click', () => {
        const page = item.dataset.page;
        console.log('Navigating to:', page);
        this.navigateTo(page);
      });
    });
  }

  handleNuiMessage(data) {
    switch (data.action) {
      case 'open':
        this.openTablet();
        break;
      case 'close':
        this.closeTablet();
        break;
      case 'updatePlayer':
        this.updatePlayerData(data.player);
        break;
      case 'updateOrders':
        this.updateOrders(data.orders);
        break;
      case 'updateSociety':
        this.updateSocietyData(data.society);
        break;
      case 'depositResult':
        this.handleDepositResult(data.result);
        break;
      case 'withdrawResult':
        this.handleWithdrawResult(data.result);
        break;
    }
  }

  openTablet() {
    document.body.classList.add('visible');
    this.loadPlayerInfo();
    this.loadSocietyData();
    this.loadOrders();
  }

  closeTablet() {
    document.body.classList.remove('visible');
  }

  closeMenu() {
    fetch(`https://${GetParentResourceName()}/close`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).catch(err => console.error('Close error:', err));
  }

  navigateTo(page) {
    this.currentPage = page;
    
    // Update active menu item
    document.querySelectorAll('.menu-item').forEach(item => {
      item.classList.remove('active');
      if (item.dataset.page === page) {
        item.classList.add('active');
      }
    });
    
    // Update pages
    document.querySelectorAll('.page').forEach(p => {
      p.classList.remove('active');
    });
    
    const targetPage = document.getElementById(`page-${page}`);
    if (targetPage) {
      targetPage.classList.add('active');
    }
    
    // Load page-specific data
    this.loadPageData(page);
  }

  loadPageData(page) {
    switch (page) {
      case 'home':
        this.updateDashboard();
        break;
      case 'orders':
        this.loadOrders();
        break;
      case 'employees':
        this.loadEmployees();
        break;
      case 'society':
        this.loadSocietyData();
        break;
      case 'stats':
        this.loadStats();
        break;
    }
  }

  async loadInitialData() {
    await this.loadPlayerInfo();
    await this.loadSocietyData();
  }

  async loadPlayerInfo() {
    try {
      const response = await fetch(`https://${GetParentResourceName()}/getPlayerInfo`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      });
      const data = await response.json();
      if (data) {
        this.updatePlayerData(data);
      }
    } catch (err) {
      console.error('Player info error:', err);
    }
  }

  updatePlayerData(data) {
    this.playerData = { ...this.playerData, ...data };
    this.updateHeader();
    this.updateDashboard();
  }

  updateHeader() {
    const playerName = document.getElementById('playerName');
    const playerGrade = document.getElementById('playerGrade');
    
    if (playerName) playerName.textContent = this.playerData.name || 'Chargement...';
    if (playerGrade) playerGrade.textContent = this.playerData.job || '-';
  }

  updateDashboard() {
    const totalDeliveries = document.getElementById('totalDeliveries');
    const totalEarnings = document.getElementById('totalEarnings');
    const reputation = document.getElementById('reputation');
    const playerLevel = document.getElementById('playerLevel');
    
    if (totalDeliveries) totalDeliveries.textContent = this.playerData.deliveries || 0;
    if (totalEarnings) totalEarnings.textContent = `${this.playerData.earnings || 0}$`;
    if (reputation) reputation.textContent = `${this.playerData.reputation || 0}%`;
    if (playerLevel) playerLevel.textContent = this.playerData.level || 1;
  }

  loadSocietyData() {
    // Trigger NUI callback - data will come back via message handler
    fetch(`https://${GetParentResourceName()}/getSocietyData`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).catch(err => console.error('Society data error:', err));
  }

  updateSocietyData(data) {
    this.societyData = { ...this.societyData, ...data };
    
    const societyBalance = document.getElementById('societyBalance');
    if (societyBalance) {
      societyBalance.textContent = `${this.societyData.balance || 0}$`;
    }
    
    this.renderTransactions();
  }

  renderTransactions() {
    const transactionsList = document.getElementById('transactionsList');
    if (!transactionsList) return;
    
    if (!this.societyData.transactions || this.societyData.transactions.length === 0) {
      transactionsList.innerHTML = `
        <div class="empty-state">
          <i class="fa-solid fa-clock-rotate-left"></i>
          <p>Aucune transaction récente</p>
        </div>
      `;
      return;
    }
    
    transactionsList.innerHTML = this.societyData.transactions
      .slice(0, 10)
      .map(tx => `
        <div class="transaction-item">
          <div class="transaction-info">
            <span class="transaction-type">${tx.action || tx.type}</span>
            <span class="transaction-date">${tx.date}</span>
          </div>
          <span class="transaction-amount ${tx.action === 'deposit' || tx.type === 'deposit' ? 'positive' : 'negative'}">
            ${tx.action === 'deposit' || tx.type === 'deposit' ? '+' : '-'}${tx.amount}$
          </span>
        </div>
      `).join('');
  }

  loadOrders() {
    // Trigger NUI callback - data will come back via message handler
    fetch(`https://${GetParentResourceName()}/getOrders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).catch(err => console.error('Orders error:', err));
  }

  updateOrders(data) {
    this.orders = data || [];
    this.renderOrders();
  }

  renderOrders() {
    const ordersList = document.getElementById('ordersList');
    if (!ordersList) return;

    if (this.orders.length === 0) {
      ordersList.innerHTML = `
        <div class="empty-state">
          <i class="fa-solid fa-box-open"></i>
          <p>Aucune commande en cours</p>
        </div>
      `;
      return;
    }

    ordersList.innerHTML = this.orders.map(order => `
      <div class="order-card">
        <div class="order-header">
          <span class="order-client">${order.client}</span>
          <span class="order-status">${order.status}</span>
        </div>
        <div class="order-details">
          <span class="order-address">${order.address}</span>
          <span class="order-reward">${order.reward}$</span>
        </div>
        <div class="order-actions">
          <button class="action-btn primary" onclick="acceptOrder(${order.id})">
            <i class="fa-solid fa-check"></i>
            Accepter
          </button>
          <button class="action-btn secondary" onclick="setGps(${order.id})">
            <i class="fa-solid fa-location-dot"></i>
            GPS
          </button>
        </div>
      </div>
    `).join('');
  }

  async loadEmployees() {
    try {
      const response = await fetch(`https://${GetParentResourceName()}/getEmployees`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      });
      const data = await response.json();
      if (data) {
        this.employees = data;
        this.renderEmployees();
      }
    } catch (err) {
      console.error('Employees error:', err);
    }
  }

  renderEmployees() {
    const employeesList = document.getElementById('employeesList');
    if (!employeesList) return;
    
    if (this.employees.length === 0) {
      employeesList.innerHTML = `
        <div class="empty-state">
          <i class="fa-solid fa-users"></i>
          <p>Aucun employé en ligne</p>
        </div>
      `;
      return;
    }
    
    employeesList.innerHTML = this.employees.map(employee => `
      <div class="employee-card">
        <div class="employee-info">
          <span class="employee-name">${employee.name}</span>
          <span class="employee-grade">${employee.grade}</span>
        </div>
        <div class="employee-actions">
          <button class="action-btn secondary" onclick="promoteEmployee('${employee.identifier}')">
            <i class="fa-solid fa-arrow-up"></i>
          </button>
          <button class="action-btn withdraw" onclick="fireEmployee('${employee.identifier}')">
            <i class="fa-solid fa-user-minus"></i>
          </button>
        </div>
      </div>
    `).join('');
  }

  async loadStats() {
    // Stats can be loaded from player data or additional endpoint
    this.updateDashboard();
  }

  async startDelivery() {
    try {
      const response = await fetch(`https://${GetParentResourceName()}/startDelivery`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      });
      const data = await response.json();
      if (data && data.success) {
        this.loadPlayerInfo();
      }
    } catch (err) {
      console.error('Start delivery error:', err);
    }
  }

  openDepositModal() {
    this.showAmountModal('Déposer', 'Montant à déposer:', (amount) => {
      if (amount && !isNaN(amount)) {
        this.depositAmount(parseInt(amount));
      }
    });
  }

  openWithdrawModal() {
    this.showAmountModal('Retirer', 'Montant à retirer:', (amount) => {
      if (amount && !isNaN(amount)) {
        this.withdrawAmount(parseInt(amount));
      }
    });
  }

  showAmountModal(title, placeholder, callback) {
    // Remove existing modal if any
    const existingModal = document.getElementById('amountModal');
    if (existingModal) existingModal.remove();

    // Create modal
    const modal = document.createElement('div');
    modal.id = 'amountModal';
    modal.className = 'amount-modal';
    modal.innerHTML = `
      <div class="modal-content">
        <h3>${title}</h3>
        <input type="number" id="amountInput" placeholder="${placeholder}" min="1" />
        <div class="modal-buttons">
          <button class="modal-btn cancel" id="cancelAmount">Annuler</button>
          <button class="modal-btn confirm" id="confirmAmount">Confirmer</button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);

    // Focus input
    setTimeout(() => document.getElementById('amountInput').focus(), 100);

    // Handle confirm
    document.getElementById('confirmAmount').addEventListener('click', () => {
      const amount = document.getElementById('amountInput').value;
      modal.remove();
      callback(amount);
    });

    // Handle cancel
    document.getElementById('cancelAmount').addEventListener('click', () => {
      modal.remove();
    });

    // Handle enter key
    document.getElementById('amountInput').addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        const amount = document.getElementById('amountInput').value;
        modal.remove();
        callback(amount);
      }
    });
  }

  depositAmount(amount) {
    // Trigger NUI callback - result will come back via message handler
    fetch(`https://${GetParentResourceName()}/depositSociety`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount })
    }).catch(err => console.error('Deposit error:', err));
  }

  withdrawAmount(amount) {
    // Trigger NUI callback - result will come back via message handler
    fetch(`https://${GetParentResourceName()}/withdrawSociety`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount })
    }).catch(err => console.error('Withdraw error:', err));
  }

  handleDepositResult(result) {
    if (result.success) {
      this.societyData.balance = result.newBalance;
      this.renderTransactions();
      this.loadSocietyData();
      this.showNotification('Dépôt effectué avec succès', 'success');
    } else {
      this.showNotification(result.message || 'Erreur lors du dépôt', 'error');
    }
  }

  handleWithdrawResult(result) {
    if (result.success) {
      this.societyData.balance = result.newBalance;
      this.renderTransactions();
      this.loadSocietyData();
      this.showNotification('Retrait effectué avec succès', 'success');
    } else {
      this.showNotification(result.message || 'Erreur lors du retrait', 'error');
    }
  }

  showNotification(message, type = 'info') {
    // Remove existing notification if any
    const existingNotification = document.getElementById('notification');
    if (existingNotification) existingNotification.remove();

    // Create notification
    const notification = document.createElement('div');
    notification.id = 'notification';
    notification.className = `notification ${type}`;
    notification.textContent = message;

    document.body.appendChild(notification);

    // Auto remove after 3 seconds
    setTimeout(() => {
      notification.remove();
    }, 3000);
  }

  startClock() {
    const updateTime = () => {
      const now = new Date();
      const hours = String(now.getHours()).padStart(2, '0');
      const minutes = String(now.getMinutes()).padStart(2, '0');
      const timeDisplay = document.getElementById('currentTime');
      if (timeDisplay) {
        timeDisplay.textContent = `${hours}:${minutes}`;
      }
    };
    
    updateTime();
    setInterval(updateTime, 1000);
  }
}

// Global functions for onclick handlers
let tablet;

window.acceptOrder = (orderId) => {
  fetch(`https://${GetParentResourceName()}/acceptOrder`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ orderId })
  }).then(() => tablet.loadOrders());
};

window.setGps = (orderId) => {
  fetch(`https://${GetParentResourceName()}/setOrderGps`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ orderId })
  });
};

window.spawnVehicle = (model) => {
  fetch(`https://${GetParentResourceName()}/spawnVehicle`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ model })
  });
};

window.promoteEmployee = (identifier) => {
  fetch(`https://${GetParentResourceName()}/promoteEmployee`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier })
  }).then(() => tablet.loadEmployees());
};

window.fireEmployee = (identifier) => {
  if (confirm('Êtes-vous sûr de vouloir licencier cet employé?')) {
    fetch(`https://${GetParentResourceName()}/fireEmployee`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier })
    }).then(() => tablet.loadEmployees());
  }
};

// Initialize tablet on DOM load
document.addEventListener('DOMContentLoaded', () => {
  tablet = new PizzaTablet();
});

document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") {
        fetch(`https://${GetParentResourceName()}/close`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({})
        });
    }
});
