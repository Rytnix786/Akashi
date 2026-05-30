import React, { useState } from 'react';
import { FieldHealthData } from '@/lib/api';

/**
 * Akashi — Crop Health Searchable Grid/Table
 * =========================================
 * Formats registered fields in a searchable data structure.
 * 
 * Reference: Akashi MVP Spec v1.0, Section 7.2
 */

interface HealthTableProps {
  fields: FieldHealthData[];
}

export default function HealthTable({ fields }: HealthTableProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUpazila, setSelectedUpazila] = useState('All');
  const [selectedStatus, setSelectedStatus] = useState('All');

  // Extract unique upazilas for filtering
  const upazilas = ['All', ...Array.from(new Set(fields.map((f) => f.upazila)))];

  const filteredFields = fields.filter((f) => {
    const matchesSearch = 
      f.farmer_name.includes(searchTerm) || 
      f.farmer_phone.includes(searchTerm) ||
      f.field_name.includes(searchTerm);
      
    const matchesUpazila = selectedUpazila === 'All' || f.upazila === selectedUpazila;
    const matchesStatus = selectedStatus === 'All' || f.health_status === selectedStatus;

    return matchesSearch && matchesUpazila && matchesStatus;
  });

  const statusBadges = {
    green: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    yellow: 'bg-amber-50 text-amber-700 border-amber-200',
    red: 'bg-red-50 text-red-700 border-red-200',
    unknown: 'bg-slate-50 text-slate-700 border-slate-200'
  };

  const statusLabels = {
    green: 'সুস্থ',
    yellow: 'সতর্কতা',
    red: 'জরুরি',
    unknown: 'মেঘলা/অজ্ঞাত'
  };

  return (
    <div className="bg-white rounded-xl shadow-md border border-slate-100 overflow-hidden">
      
      {/* Table Filters Header */}
      <div className="p-5 border-b border-slate-100 bg-slate-50/50 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <h3 className="text-lg font-bold text-slate-800">নিবন্ধিত জমি ও স্বাস্থ্য তথ্য</h3>
        
        <div className="flex flex-wrap items-center gap-3">
          {/* Search bar */}
          <input
            type="text"
            className="px-4 py-2 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary placeholder:text-slate-400 w-full sm:w-48"
            placeholder="কৃষকের নাম/মোবাইল/জমির নাম..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />

          {/* Upazila select */}
          <select
            className="px-3 py-2 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-slate-700"
            value={selectedUpazila}
            onChange={(e) => setSelectedUpazila(e.target.value)}
          >
            {upazilas.map((uz) => (
              <option key={uz} value={uz}>{uz === 'All' ? 'সব উপজেলা' : uz}</option>
            ))}
          </select>

          {/* Status select */}
          <select
            className="px-3 py-2 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-slate-700"
            value={selectedStatus}
            onChange={(e) => setSelectedStatus(e.target.value)}
          >
            <option value="All">সব অবস্থা</option>
            <option value="green">সুস্থ (সবুজ)</option>
            <option value="yellow">সতর্কতা (হলুদ)</option>
            <option value="red">ঝুঁকিপূর্ণ (লাল)</option>
          </select>
        </div>
      </div>

      {/* Responsive Table Grid */}
      <div className="overflow-x-auto">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="bg-slate-50 border-b border-slate-100 text-xs font-semibold text-slate-500 uppercase tracking-wider">
              <th className="px-6 py-4">জমির মালিক (কৃষক)</th>
              <th className="px-6 py-4">জমির নাম ও ফসল</th>
              <th className="px-6 py-4">উপজেলা</th>
              <th className="px-6 py-4">জমির আয়তন</th>
              <th className="px-6 py-4 text-center">স্বাস্থ্যাবস্থা</th>
              <th className="px-6 py-4 text-right">গড় NDVI</th>
              <th className="px-6 py-4 text-right">সর্বশেষ আপডেট</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100 text-sm">
            {filteredFields.length > 0 ? (
              filteredFields.map((f) => (
                <tr key={f.id} className="hover:bg-slate-50/50 transition-colors">
                  {/* Farmer details */}
                  <td className="px-6 py-4">
                    <div className="font-semibold text-slate-800">{f.farmer_name}</div>
                    <div className="text-xs text-slate-400 font-medium">{f.farmer_phone}</div>
                  </td>
                  
                  {/* Field details */}
                  <td className="px-6 py-4">
                    <div className="font-semibold text-slate-800">{f.field_name}</div>
                    <div className="inline-flex items-center mt-0.5 px-2 py-0.5 bg-primary/10 text-primary text-[10px] font-bold rounded">
                      {f.crop_type}
                    </div>
                  </td>
                  
                  {/* Upazila */}
                  <td className="px-6 py-4 font-medium text-slate-600">{f.upazila}</td>
                  
                  {/* Area */}
                  <td className="px-6 py-4 font-medium text-slate-600">
                    <div>{f.area_acres} একর</div>
                    <div className="text-xs text-slate-400">{f.area_bigha} বিঘা</div>
                  </td>
                  
                  {/* Health status */}
                  <td className="px-6 py-4 text-center">
                    <span className={`inline-block px-2.5 py-1 border text-xs font-bold rounded-full ${statusBadges[f.health_status]}`}>
                      ● {statusLabels[f.health_status]}
                    </span>
                  </td>
                  
                  {/* NDVI mean */}
                  <td className="px-6 py-4 text-right font-bold text-slate-700">
                    {f.ndvi_mean !== null ? f.ndvi_mean.toFixed(4) : 'N/A'}
                  </td>
                  
                  {/* Reading Date */}
                  <td className="px-6 py-4 text-right font-medium text-slate-500">{f.reading_date}</td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={7} className="px-6 py-8 text-center text-slate-400 font-medium">
                  কোনো জমি পাওয়া যায়নি।
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
