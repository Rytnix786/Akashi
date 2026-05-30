import React from 'react';

/**
 * Akashi — Dashboard Statistics Card
 * ==================================
 * Displays critical counts and ratios with clean visual accents.
 * 
 * Reference: Akashi MVP Spec v1.0, Section 7.2
 */

interface StatsCardProps {
  title: string;
  value: string | number;
  icon: React.ReactNode;
  description?: string;
  trend?: {
    value: number;
    label: string;
    isPositive: boolean;
  };
  accentColor?: 'primary' | 'secondary' | 'tertiary' | 'error';
}

export default function StatsCard({
  title,
  value,
  icon,
  description,
  trend,
  accentColor = 'primary'
}: StatsCardProps) {
  const borderAccents = {
    primary: 'border-l-primary',
    secondary: 'border-l-secondary',
    tertiary: 'border-l-tertiary',
    error: 'border-l-error'
  };

  const bgAccents = {
    primary: 'bg-primary/5 text-primary',
    secondary: 'bg-secondary/5 text-secondary',
    tertiary: 'bg-tertiary/5 text-tertiary',
    error: 'bg-error/5 text-error'
  };

  return (
    <div className={`bg-white rounded-xl shadow-md border border-slate-100 border-l-4 ${borderAccents[accentColor]} p-5 hover:shadow-lg transition-all duration-300 flex items-center justify-between`}>
      <div className="space-y-1.5">
        <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">{title}</span>
        <div className="flex items-baseline space-x-2">
          <span className="text-3xl font-extrabold text-slate-800 tracking-tight">{value}</span>
          {trend && (
            <span className={`text-xs font-bold ${trend.isPositive ? 'text-emerald-500' : 'text-error'}`}>
              {trend.isPositive ? '↑' : '↓'} {trend.value}%
            </span>
          )}
        </div>
        {description && <p className="text-xs text-slate-500 font-medium">{description}</p>}
      </div>
      <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${bgAccents[accentColor]}`}>
        {icon}
      </div>
    </div>
  );
}
