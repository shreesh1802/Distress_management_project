import { useMemo } from 'react';
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
import './DistressTrendChart.css';

interface DistressTrendItem {
  date: string;
  potholes: number;
  cracks: number;
  rutting: number;
}

export default function DistressTrendChart() {
  // Generate daily mock data for the last 30 days with wave fluctuations
  const trendData = useMemo<DistressTrendItem[]>(() => {
    const data: DistressTrendItem[] = [];
    const startDay = 20; // Starts from May 20, 2026
    for (let i = 0; i < 30; i++) {
      const date = new Date(2026, 4, startDay + i); // 4 represents May
      const dateLabel = date.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
      });

      // Daily fluctuations
      const potholes = Math.round(18 + Math.sin(i * 0.45) * 8 + (i % 3) * 2 + Math.random() * 4);
      const cracks = Math.round(26 + Math.cos(i * 0.35) * 11 + (i % 4) * 3 + Math.random() * 5);
      const rutting = Math.round(10 + Math.sin(i * 0.5) * 4 + (i % 2) * 2 + Math.random() * 3);

      data.push({
        date: dateLabel,
        potholes,
        cracks,
        rutting,
      });
    }
    return data;
  }, []);

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
      </div>
    </article>
  );
}
