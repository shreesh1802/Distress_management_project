import { Film, ShieldAlert, AlertTriangle, FileText } from 'lucide-react'
import KPICard from './KPICard'

type KPISectionProps = {
  distressCount: number
  criticalCount: number
  pendingCount: number
  reportsCount: number
}

export default function KPISection({
  distressCount,
  criticalCount,
  pendingCount,
  reportsCount,
}: KPISectionProps) {

  const kpiItems = [
    {
      title: 'Videos Uploaded',
      value: '42',
      icon: <Film size={18} />,
      trend: '+8%',
      isPositive: true,
      sparklineData: [30, 32, 35, 38, 40, 42],
      comparison: 'vs last week',
    },
    {
      title: 'Total Distresses',
      value: distressCount || 87,
      icon: <ShieldAlert size={18} />,
      trend: '+3.4%',
      isPositive: false,
      sparklineData: [75, 78, 80, 84, 87],
      comparison: 'vs yesterday',
    },
    {
      title: 'Critical Distresses',
      value: criticalCount || 12,
      icon: <AlertTriangle size={18} />,
      trend: '+0%',
      isPositive: true,
      sparklineData: [12, 12, 12, 12, 12],
      comparison: 'vs yesterday',
    },
    {
      title: 'Reports Generated',
      value: reportsCount || 18,
      icon: <FileText size={18} />,
      trend: '+12%',
      isPositive: true,
      sparklineData: [12, 14, 15, 17, 18],
      comparison: 'vs yesterday',
    },
  ]

  return (
    <section>
      <div className="dash-row-inner">
        {kpiItems.map((item) => (
          <KPICard 
            key={item.title} 
            title={item.title} 
            value={item.value} 
            icon={item.icon}
            trend={item.trend}
            isPositive={item.isPositive}
            sparklineData={item.sparklineData}
            comparison={item.comparison}
          />
        ))}
      </div>
    </section>
  )
}

