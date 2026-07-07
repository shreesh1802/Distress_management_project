import { useMemo, useEffect, useState } from 'react';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts';
import { TrendingUp, AlertTriangle } from 'lucide-react';
import apiService, { RoadDistressResponse } from '../../services/api/apiService';
import './DistressTrendChart.css';

interface DistressTrendItem {
  date: string;
  potholes: number;
  cracks: number;
  rutting: number;
}

export default function DistressTrendChart() {
  const [data, setData] = useState<RoadDistressResponse[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchLogs = async () => {
      try {
        const logs = await apiService.getDistressLogs(0, 1000);
        setData(logs);
      } catch (err) {
        console.error("Failed to load distress trend logs:", err);
      } finally {
        setIsLoading(false);
      }
    };
    fetchLogs();
  }, []);

  const { trendData, hasData } = useMemo(() => {
    const dailyMap: Record<string, { potholes: number; cracks: number; rutting: number }> = {};
    const dates: Date[] = [];
    
    // Set up last 30 days
    for (let i = 29; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const key = d.toISOString().split('T')[0];
      dailyMap[key] = { potholes: 0, cracks: 0, rutting: 0 };
      dates.push(d);
    }

    data.forEach(item => {
      const dateStr = item.detected_at?.split('T')[0] || item.created_at?.split('T')[0];
      if (dateStr && dailyMap[dateStr]) {
        const type = item.distress_type.toLowerCase();
        if (type.includes('pothole')) {
          dailyMap[dateStr].potholes++;
        } else if (type.includes('crack') || type.includes('alligator')) {
          dailyMap[dateStr].cracks++;
        } else if (type.includes('rut')) {
          dailyMap[dateStr].rutting++;
        }
      }
    });

    const trend = dates.map(d => {
      const key = d.toISOString().split('T')[0];
      const label = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      return {
        date: label,
        ...dailyMap[key]
      };
    });

    const active = trend.some(t => t.potholes > 0 || t.cracks > 0 || t.rutting > 0);

    return {
      trendData: trend,
      hasData: active
    };
  }, [data]);

  return (
    <article className="distress-trend-card" aria-labelledby="trend-title">
      <header className="distress-trend-card__header">
        <div className="distress-trend-card__title-group">
          <TrendingUp className="distress-trend-card__icon text-purple" size={18} />
          <h3 id="trend-title" className="distress-trend-card__title">
            Distress Detections Trend (Last 30 Days)
          </h3>
        </div>
        <div className="distress-trend-card__badge">
          <AlertTriangle size={12} className="text-red" />
          <span>Real-time AI telemetry</span>
        </div>
      </header>

      <div className="distress-trend-card__body">
        {isLoading ? (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '320px', color: 'var(--secondary-text)', fontSize: '13px' }}>
            Loading trend data...
          </div>
        ) : !hasData ? (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '320px', color: 'var(--secondary-text)', fontSize: '13px' }}>
            No data available
          </div>
        ) : (
          <div className="distress-trend-card__canvas">
            <ResponsiveContainer width="100%" height={320}>
              <AreaChart data={trendData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  {/* Potholes Red Gradient */}
                  <linearGradient id="gradPotholes" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#C45C45" stopOpacity={0.25} />
                    <stop offset="95%" stopColor="#C45C45" stopOpacity={0.0} />
                  </linearGradient>

                  {/* Cracks Purple Gradient */}
                  <linearGradient id="gradCracks" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#7B8260" stopOpacity={0.25} />
                    <stop offset="95%" stopColor="#7B8260" stopOpacity={0.0} />
                  </linearGradient>

                  {/* Rutting Yellow Gradient */}
                  <linearGradient id="gradRutting" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#D6A23A" stopOpacity={0.2} />
                    <stop offset="95%" stopColor="#D6A23A" stopOpacity={0.0} />
                  </linearGradient>
                </defs>

                <CartesianGrid strokeDasharray="3 3" stroke="rgba(148, 163, 184, 0.05)" />
                <XAxis dataKey="date" stroke="#64748b" fontSize={10} tickLine={false} />
                <YAxis stroke="#64748b" fontSize={10} tickLine={false} />
                
                <Tooltip
                  contentStyle={{
                    background: '#0f172a',
                    border: '1px solid rgba(148, 163, 184, 0.2)',
                    borderRadius: '8px',
                    boxShadow: '0 10px 25px rgba(0, 0, 0, 0.4)',
                  }}
                  labelStyle={{ color: '#cbd5e1', fontWeight: 'bold', fontSize: '11px' }}
                  itemStyle={{ fontSize: '11px', padding: '1px 0' }}
                />

                <Legend iconSize={8} iconType="circle" wrapperStyle={{ fontSize: '11px', paddingTop: '10px' }} />

                {/* Area Plots */}
                <Area
                  type="monotone"
                  dataKey="potholes"
                  name="Potholes"
                  stroke="#C45C45"
                  strokeWidth={2}
                  fillOpacity={1}
                  fill="url(#gradPotholes)"
                />
                <Area
                  type="monotone"
                  dataKey="cracks"
                  name="Cracks"
                  stroke="#7B8260"
                  strokeWidth={2}
                  fillOpacity={1}
                  fill="url(#gradCracks)"
                />
                <Area
                  type="monotone"
                  dataKey="rutting"
                  name="Rutting"
                  stroke="#D6A23A"
                  strokeWidth={2}
                  fillOpacity={1}
                  fill="url(#gradRutting)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>
    </article>
  );
}
