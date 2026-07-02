import { useEffect, useState, useMemo } from 'react'
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import apiService from '../../services/api/apiService'
import type { MaintenanceSummaryResponse } from '../../services/api/apiService'
import './MaintenanceAnalytics.css'

interface MetricItem {
  id: string
  label: string
  value: string | number
  status: 'success' | 'warning' | 'danger' | 'info'
}

export default function MaintenanceAnalytics() {
  const [summary, setSummary] = useState<MaintenanceSummaryResponse | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  useEffect(() => {
    let active = true;
    const loadSummary = async () => {
      try {
        // Trigger recommendation computation for any new distress logs
        await apiService.getMaintenanceRecommendations();
        const res = await apiService.getMaintenanceSummary();
        if (active) {
          setSummary(res);
          setIsLoading(false);
        }
      } catch (err) {
        console.error("Failed to load maintenance summary from API:", err);
      }
    };
    loadSummary();
    return () => {
      active = false;
    };
  }, []);

  const metrics = useMemo((): MetricItem[] => {
    if (!summary) return [];

    const formatCost = (val: number): string => {
      if (val >= 10000000) return `₹${(val / 10000000).toFixed(1)}Cr`;
      if (val >= 100000) return `₹${(val / 100000).toFixed(1)}L`;
      return `₹${val.toLocaleString()}`;
    };

    return [
      {
        id: 'completed',
        label: 'Completed Repairs',
        value: summary.completed_repairs,
        status: 'success',
      },
      {
        id: 'in-progress',
        label: 'In Progress',
        value: summary.in_progress_repairs,
        status: 'warning',
      },
      {
        id: 'pending',
        label: 'Pending Repairs',
        value: summary.pending_repairs,
        status: 'danger',
      },
      {
        id: 'cost',
        label: 'Estimated Cost',
        value: formatCost(summary.total_cost),
        status: 'info',
      },
    ];
  }, [summary]);

  const chartData = useMemo(() => {
    if (!summary) return [];
    return summary.monthly_repairs;
  }, [summary]);

  if (isLoading || !summary) {
    return (
      <div className="maintenance-analytics-container flex-center" style={{ minHeight: '260px', display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
        <div className="dashboard-page__spinner" style={{ width: '24px', height: '24px', margin: 'auto' }} />
        <p style={{ color: '#94a3b8', fontSize: '12px', marginTop: '8px', textAlign: 'center' }}>
          Loading real-time maintenance stats...
        </p>
      </div>
    );
  }

  return (
    <div className="maintenance-analytics-container">
      {/* Top Row: Mini KPI Cards */}
      <div className="maintenance-analytics-metrics">
        {metrics.map((metric) => (
          <div
            key={metric.id}
            className={`maintenance-metric-card maintenance-metric-card--${metric.status}`}
          >
            <span className="maintenance-metric-card__label">{metric.label}</span>
            <span className="maintenance-metric-card__value">{metric.value}</span>
          </div>
        ))}
      </div>

      {/* Bottom Row: Bar Chart */}
      <div className="maintenance-analytics-chart-wrapper">
        <h3 className="maintenance-analytics-chart-title">Repairs Completed (Monthly)</h3>
        <div className="maintenance-analytics-chart">
          <ResponsiveContainer width="100%" height={140}>
            <BarChart data={chartData} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
              <CartesianGrid stroke="rgba(148, 163, 184, 0.12)" strokeDasharray="4 4" vertical={false} />
              <XAxis 
                dataKey="month" 
                stroke="#94a3b8" 
                fontSize={11} 
                tickLine={false} 
                axisLine={false}
              />
              <YAxis 
                stroke="#94a3b8" 
                fontSize={11} 
                tickLine={false} 
                axisLine={false} 
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: '#111827',
                  border: '1px solid rgba(148, 163, 184, 0.24)',
                  borderRadius: '8px',
                  fontSize: '12px',
                  color: '#f8fafc',
                }}
                itemStyle={{ color: '#f8fafc' }}
                labelStyle={{ color: '#cbd5e1', fontWeight: 600 }}
                cursor={{ fill: 'rgba(148, 163, 184, 0.06)' }}
              />
              <Bar 
                dataKey="repairs" 
                name="Repairs" 
                fill="#7B8260" 
                radius={[4, 4, 0, 0]} 
                maxBarSize={32}
              />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
