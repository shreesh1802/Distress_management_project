import { useMemo } from 'react'
import {
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
} from 'recharts'
import type { RoadDistressResponse } from '../../services/api/apiService'

type DistressDistributionItem = {
  name: string
  value: number
  color: string
}

export interface DistressDistributionChartProps {
  data: RoadDistressResponse[]
}

const COLORS = ['#C45C45', '#D6A23A', '#C87B35', '#8FA06A', '#6B88C7'];

function DistressDistributionChart({ data }: DistressDistributionChartProps) {
  const { chartData, totalCount, hasData } = useMemo(() => {
    // Dynamic grouping based on distress_type strings
    const counts: Record<string, number> = {
      'Potholes': 0,
      'Cracks': 0,
      'Alligator Cracks': 0,
      'Rutting': 0,
      'Others': 0
    };

    data.forEach((item) => {
      const type = item.distress_type.toLowerCase();
      if (type.includes('pothole')) {
        counts['Potholes']++;
      } else if (type.includes('alligator')) {
        counts['Alligator Cracks']++;
      } else if (type.includes('crack')) {
        counts['Cracks']++;
      } else if (type.includes('rut')) {
        counts['Rutting']++;
      } else {
        counts['Others']++;
      }
    });

    const items: DistressDistributionItem[] = [
      { name: 'Potholes', value: counts['Potholes'], color: COLORS[0] },
      { name: 'Cracks', value: counts['Cracks'], color: COLORS[1] },
      { name: 'Alligator Cracks', value: counts['Alligator Cracks'], color: COLORS[2] },
      { name: 'Rutting', value: counts['Rutting'], color: COLORS[3] },
      { name: 'Others', value: counts['Others'], color: COLORS[4] }
    ];

    const activeItems = items.filter(item => item.value > 0);
    const hasData = activeItems.length > 0;
    
    const finalItems = activeItems;

    const total = finalItems.reduce((sum, item) => sum + item.value, 0);

    return {
      chartData: finalItems,
      totalCount: total,
      hasData
    };
  }, [data]);

  if (!hasData) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', width: '100%', height: '220px', color: 'var(--secondary-text)', fontSize: '13px' }}>
        No data available
      </div>
    );
  }

  return (
    <div style={{ position: 'relative', width: '100%', height: '220px' }}>
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={chartData}
            dataKey="value"
            nameKey="name"
            innerRadius="62%"
            outerRadius="80%"
            paddingAngle={3}
          >
            {chartData.map((item) => (
              <Cell key={item.name} fill={item.color} />
            ))}
          </Pie>
          <Tooltip
            contentStyle={{
              backgroundColor: '#111827',
              border: '1px solid rgba(148, 163, 184, 0.24)',
              borderRadius: '10px',
              color: '#f8fafc',
            }}
            itemStyle={{ color: '#f8fafc' }}
            labelStyle={{ color: '#cbd5e1' }}
          />
          <Legend 
            layout="vertical" 
            align="right" 
            verticalAlign="middle" 
            iconType="circle"
            formatter={(value) => {

              const item = chartData.find(d => d.name === value);
              if (!item) return value;
              const percent = Math.round((item.value / totalCount) * 100);
              return (
                <span style={{ fontSize: '12px', color: 'var(--primary-text)', fontWeight: 500 }}>
                  <span style={{ marginRight: '8px', color: 'var(--secondary-text)' }}>{value}</span>
                  <span style={{ fontWeight: 600 }}>{percent}% ({item.value})</span>
                </span>
              );
            }}
          />
        </PieChart>
      </ResponsiveContainer>
      
      {/* Centered Total Indicator */}
      <div style={{
        position: 'absolute',
        top: '50%',
        left: '30%',
        transform: 'translate(-50%, -50%)',
        textAlign: 'center',
        pointerEvents: 'none'
      }}>
        <div style={{ fontSize: '20px', fontWeight: 800, color: 'var(--primary-text)', lineHeight: 1 }}>
          {totalCount.toLocaleString()}
        </div>
        <div style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase', marginTop: '4px', letterSpacing: '0.05em' }}>
          Total
        </div>
      </div>
    </div>
  )
}

export default DistressDistributionChart
