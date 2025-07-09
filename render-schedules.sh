#!/bin/bash

# render-schedules.sh
# Script to generate an HTML file displaying AKS upgrade schedules

SCHEDULES_DIR="./schedules"
WEBROOT_DIR="./webroot"
OUTPUT_FILE="$WEBROOT_DIR/index.html"

# Create webroot directory if it doesn't exist
mkdir -p "$WEBROOT_DIR"

# Function to convert CSV data to JSON
csv_to_json() {
    local csv_data="$1"
    local json_array="["
    local first_line=true
    
    while IFS=',' read -r subscription_id resource_group cluster_name target_version scheduled_time; do
        # Skip comment lines
        [[ $subscription_id =~ ^#.*$ ]] && continue
        # Skip empty lines
        [[ -z "$subscription_id" ]] && continue
        
        if [ "$first_line" = true ]; then
            first_line=false
        else
            json_array+=","
        fi
        
        json_array+="{\"subscriptionId\":\"$subscription_id\",\"resourceGroup\":\"$resource_group\",\"clusterName\":\"$cluster_name\",\"targetVersion\":\"$target_version\",\"scheduledTime\":\"$scheduled_time\"}"
    done <<< "$csv_data"
    
    json_array+="]"
    echo "$json_array"
}

# Read all CSV files from schedules directory
all_schedules=""
for file in "$SCHEDULES_DIR"/*.txt; do
    if [ -f "$file" ]; then
        echo "Processing file: $file"
        file_content=$(grep -v '^#' "$file" | grep -v '^$')
        if [ ! -z "$file_content" ]; then
            all_schedules+="$file_content"$'\n'
        fi
    fi
done

# Convert to JSON
json_data=$(csv_to_json "$all_schedules")

# Generate HTML file
cat > "$OUTPUT_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AKS Upgrade Schedule Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        body {
            background-color: #f8f9fa;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem 0;
            margin-bottom: 2rem;
        }
        
        .card {
            border: none;
            border-radius: 15px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            margin-bottom: 2rem;
        }
        
        .table-responsive {
            border-radius: 10px;
            overflow: hidden;
        }
        
        .table {
            margin-bottom: 0;
        }
        
        .table thead th {
            background-color: #495057;
            color: white;
            border: none;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.85rem;
            letter-spacing: 0.5px;
        }
        
        .table tbody td {
            border-color: #e9ecef;
            vertical-align: middle;
            padding: 1rem 0.75rem;
        }
        
        .table tbody td:first-child {
            min-width: 120px;
            white-space: nowrap;
        }
        
        .table tbody tr:hover {
            background-color: #f8f9fa;
        }
        
        .status-badge {
            padding: 0.4rem 0.8rem;
            border-radius: 20px;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            white-space: nowrap;
            display: inline-block;
        }
        
        .status-urgent {
            background-color: #dc3545;
            color: white;
            animation: pulse 2s infinite;
        }
        
        .status-upcoming {
            background-color: #ffc107;
            color: #212529;
        }
        
        .status-future {
            background-color: #28a745;
            color: white;
        }
        
        .status-past {
            background-color: #6c757d;
            color: white;
        }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.7; }
            100% { opacity: 1; }
        }
        
        .urgent-row {
            background-color: #fff5f5 !important;
            border-left: 4px solid #dc3545;
        }
        
        .urgent-row:hover {
            background-color: #ffeaea !important;
        }
        
        .stats-card {
            background: white;
            border-radius: 10px;
            padding: 1.5rem;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .stats-number {
            font-size: 2rem;
            font-weight: bold;
            margin-bottom: 0.5rem;
        }
        
        .stats-label {
            color: #6c757d;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .refresh-btn {
            position: fixed;
            bottom: 2rem;
            right: 2rem;
            z-index: 1000;
        }
        
        .time-info {
            font-size: 0.85rem;
            color: #6c757d;
            margin-top: 0.5rem;
        }
        
        .cluster-name {
            font-weight: 600;
            color: #495057;
        }
        
        .version-badge {
            background-color: #e9ecef;
            color: #495057;
            padding: 0.25rem 0.5rem;
            border-radius: 5px;
            font-family: 'Courier New', monospace;
            font-size: 0.8rem;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <div class="row align-items-center">
                <div class="col-md-8">
                    <h1 class="mb-0"><i class="fas fa-calendar-alt me-3"></i>AKS Upgrade Schedule Dashboard</h1>
                    <p class="mb-0 mt-2">Real-time monitoring of Azure Kubernetes Service upgrade schedules</p>
                </div>
                <div class="col-md-4 text-md-end">
                    <div class="time-info">
                        <i class="fas fa-clock me-2"></i>
                        <span id="currentTime"></span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="container">
        <!-- Statistics Cards -->
        <div class="row mb-4">
            <div class="col-md-3 mb-3">
                <div class="stats-card">
                    <div class="stats-number text-danger" id="urgentCount">0</div>
                    <div class="stats-label">Next 24 Hours</div>
                </div>
            </div>
            <div class="col-md-3 mb-3">
                <div class="stats-card">
                    <div class="stats-number text-warning" id="upcomingCount">0</div>
                    <div class="stats-label">This Week</div>
                </div>
            </div>
            <div class="col-md-3 mb-3">
                <div class="stats-card">
                    <div class="stats-number text-success" id="futureCount">0</div>
                    <div class="stats-label">Future</div>
                </div>
            </div>
            <div class="col-md-3 mb-3">
                <div class="stats-card">
                    <div class="stats-number text-secondary" id="totalCount">0</div>
                    <div class="stats-label">Total</div>
                </div>
            </div>
        </div>

        <!-- Schedule Table -->
        <div class="card">
            <div class="card-header bg-white py-3">
                <div class="row align-items-center">
                    <div class="col">
                        <h5 class="mb-0"><i class="fas fa-list me-2"></i>Upgrade Schedule</h5>
                    </div>
                    <div class="col-auto">
                        <div class="btn-group" role="group">
                            <button type="button" class="btn btn-outline-primary btn-sm" onclick="filterTable('all')">All</button>
                            <button type="button" class="btn btn-outline-danger btn-sm" onclick="filterTable('urgent')">Next 24h</button>
                            <button type="button" class="btn btn-outline-warning btn-sm" onclick="filterTable('upcoming')">This Week</button>
                            <button type="button" class="btn btn-outline-success btn-sm" onclick="filterTable('future')">Future</button>
                        </div>
                    </div>
                </div>
            </div>
            <div class="table-responsive">
                <table class="table table-hover" id="scheduleTable">
                    <thead>
                        <tr>
                            <th><i class="fas fa-exclamation-circle me-1"></i>Status</th>
                            <th><i class="fas fa-cloud me-1"></i>Subscription ID</th>
                            <th><i class="fas fa-layer-group me-1"></i>Resource Group</th>
                            <th><i class="fas fa-server me-1"></i>Cluster Name</th>
                            <th><i class="fas fa-tag me-1"></i>Target Version</th>
                            <th><i class="fas fa-calendar-check me-1"></i>Scheduled Time</th>
                            <th><i class="fas fa-clock me-1"></i>Time Until</th>
                        </tr>
                    </thead>
                    <tbody id="scheduleTableBody">
                        <!-- Data will be populated by JavaScript -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Refresh Button -->
    <button class="btn btn-primary btn-lg refresh-btn" onclick="location.reload()" title="Refresh Data">
        <i class="fas fa-sync-alt"></i>
    </button>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Schedule data will be inserted here
        const scheduleData = SCHEDULE_DATA_PLACEHOLDER;
        
        let currentFilter = 'all';
        
        function updateCurrentTime() {
            const now = new Date();
            document.getElementById('currentTime').textContent = now.toLocaleString();
        }
        
        function getStatus(scheduledTime) {
            const now = new Date();
            const scheduled = new Date(scheduledTime);
            const diffHours = (scheduled - now) / (1000 * 60 * 60);
            
            if (diffHours < 0) {
                return 'past';
            } else if (diffHours <= 24) {
                return 'urgent';
            } else if (diffHours <= 168) { // 7 days
                return 'upcoming';
            } else {
                return 'future';
            }
        }
        
        function getStatusBadge(status) {
            const badges = {
                'urgent': '<span class="status-badge status-urgent"><i class="fas fa-exclamation-triangle me-1"></i>Next 24h</span>',
                'upcoming': '<span class="status-badge status-upcoming"><i class="fas fa-clock me-1"></i>This Week</span>',
                'future': '<span class="status-badge status-future"><i class="fas fa-calendar-plus me-1"></i>Future</span>',
                'past': '<span class="status-badge status-past"><i class="fas fa-check me-1"></i>Completed</span>'
            };
            return badges[status] || badges['future'];
        }
        
        function getTimeUntil(scheduledTime) {
            const now = new Date();
            const scheduled = new Date(scheduledTime);
            const diff = scheduled - now;
            
            if (diff < 0) {
                const pastDiff = Math.abs(diff);
                const days = Math.floor(pastDiff / (1000 * 60 * 60 * 24));
                const hours = Math.floor((pastDiff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
                
                if (days > 0) {
                    return `${days}d ${hours}h ago`;
                } else {
                    return `${hours}h ago`;
                }
            }
            
            const days = Math.floor(diff / (1000 * 60 * 60 * 24));
            const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
            const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
            
            if (days > 0) {
                return `${days}d ${hours}h`;
            } else if (hours > 0) {
                return `${hours}h ${minutes}m`;
            } else {
                return `${minutes}m`;
            }
        }
        
        function formatDateTime(dateTimeString) {
            const date = new Date(dateTimeString);
            return date.toLocaleString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                timeZoneName: 'short'
            });
        }
        
        function renderTable() {
            const tbody = document.getElementById('scheduleTableBody');
            const now = new Date();
            
            // Sort by scheduled time
            const sortedData = [...scheduleData].sort((a, b) => new Date(a.scheduledTime) - new Date(b.scheduledTime));
            
            let urgentCount = 0, upcomingCount = 0, futureCount = 0, pastCount = 0;
            
            tbody.innerHTML = '';
            
            sortedData.forEach(item => {
                const status = getStatus(item.scheduledTime);
                
                // Count items by status
                switch(status) {
                    case 'urgent': urgentCount++; break;
                    case 'upcoming': upcomingCount++; break;
                    case 'future': futureCount++; break;
                    case 'past': pastCount++; break;
                }
                
                // Apply filter
                if (currentFilter !== 'all' && currentFilter !== status) {
                    return;
                }
                
                const row = document.createElement('tr');
                if (status === 'urgent') {
                    row.classList.add('urgent-row');
                }
                
                row.innerHTML = `
                    <td>${getStatusBadge(status)}</td>
                    <td><code style="font-size: 0.8rem;">${item.subscriptionId}</code></td>
                    <td><strong>${item.resourceGroup}</strong></td>
                    <td><span class="cluster-name">${item.clusterName}</span></td>
                    <td><span class="version-badge">${item.targetVersion}</span></td>
                    <td>${formatDateTime(item.scheduledTime)}</td>
                    <td><strong>${getTimeUntil(item.scheduledTime)}</strong></td>
                `;
                
                tbody.appendChild(row);
            });
            
            // Update statistics
            document.getElementById('urgentCount').textContent = urgentCount;
            document.getElementById('upcomingCount').textContent = upcomingCount;
            document.getElementById('futureCount').textContent = futureCount;
            document.getElementById('totalCount').textContent = scheduleData.length;
        }
        
        function filterTable(filter) {
            currentFilter = filter;
            
            // Update button states
            document.querySelectorAll('.btn-group button').forEach(btn => {
                btn.classList.remove('active');
            });
            
            if (filter === 'all') {
                document.querySelector('button[onclick="filterTable(\'all\')"]').classList.add('active');
            } else if (filter === 'urgent') {
                document.querySelector('button[onclick="filterTable(\'urgent\')"]').classList.add('active');
            } else if (filter === 'upcoming') {
                document.querySelector('button[onclick="filterTable(\'upcoming\')"]').classList.add('active');
            } else if (filter === 'future') {
                document.querySelector('button[onclick="filterTable(\'future\')"]').classList.add('active');
            }
            
            renderTable();
        }
        
        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            updateCurrentTime();
            renderTable();
            
            // Update time every minute
            setInterval(updateCurrentTime, 60000);
            
            // Update table every 5 minutes
            setInterval(renderTable, 300000);
            
            // Set default filter to show all
            filterTable('all');
        });
    </script>
</body>
</html>
EOF

# Replace placeholder with actual JSON data
sed -i "s/SCHEDULE_DATA_PLACEHOLDER/$json_data/g" "$OUTPUT_FILE"

echo "HTML file generated successfully: $OUTPUT_FILE"
echo "Total schedules processed: $(echo "$json_data" | jq '. | length' 2>/dev/null || echo "Unknown")"