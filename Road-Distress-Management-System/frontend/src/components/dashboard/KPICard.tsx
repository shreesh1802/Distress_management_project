import type { ReactNode } from 'react'
import './KPICard.css'

type KPICardProps = {
  title: string
  value: string | number
  icon: ReactNode
  trend?: string
  isPositive?: boolean
  comparison?: string
  sparklineData?: number[]
}

export default function KPICard({
  title,
  value,
  icon,
  trend = '+4.2%',
  isPositive = true,
  comparison = 'vs yesterday',
  sparklineData = [35, 45, 40, 55, 50, 65, 60],
}: KPICardProps) {
  
  // Calculate SVG sparkline points
  const points = sparklineData
    .map((val, index) => {
      const x = (index / (sparklineData.length - 1)) * 60;
      const y = 20 - ((val - Math.min(...sparklineData)) / (Math.max(...sparklineData) - Math.min(...sparklineData) || 1)) * 16;
      return `${x},${y}`;
    })
    .join(' ');

  const titleKey = title.toLowerCase().replace(/[^a-z]/g, '');

  return (
    <article className="premium-kpi-card premium-card animate-fade-in" aria-label={title}>
      <div className="kpi-header-row">
        <div className={`kpi-icon-container kpi-icon-container--${titleKey}`}>
          {icon}
        </div>
        <span className="kpi-title-label">{title}</span>
      </div>
      
      <p className="kpi-value-num">{value}</p>
    </article>
  )
}
