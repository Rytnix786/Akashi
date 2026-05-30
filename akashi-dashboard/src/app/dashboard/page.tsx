'use client';

/**
 * Akashi — District Analytics Dashboard Overview
 * =============================================
 * Interactive Next.js dashboard for DAE officers displaying stats and field maps.
 * Uses dynamic leaflet rendering and fallback support.
 * 
 * Reference: Akashi MVP Spec v1.0, Section 7
 */

import React, { useState, useEffect } from 'react';
import dynamic from 'next/dynamic';
import { useRouter } from 'next/navigation';
import { 
  getDistrictSummary, 
  getDistrictFields, 
  DistrictSummary, 
  FieldHealthData 
} from '@/lib/api';
import StatsCard from '@/components/StatsCard';
import HealthTable from '@/components/HealthTable';

// Dynamically import Leaflet Map to prevent Node.js window errors during server rendering
const DistrictMap = dynamic(() => import('@/components/DistrictMap'), {
  ssr: false,
  loading: () => (
    <div className="w-full h-full bg-slate-100/60 animate-pulse flex items-center justify-center rounded-2xl border border-slate-200/40 min-h-[450px]">
      <span className="text-xs font-semibold text-slate-400">স্যাটেলাইট ম্যাপ লোড হচ্ছে...</span>
    </div>
  )
});

export default function DashboardPage() {
  const router = useRouter();
  const [district, setDistrict] = useState('Tangail');
  const [summary, setSummary] = useState<DistrictSummary | null>(null);
  const [fields, setFields] = useState<FieldHealthData[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [navTab, setNavTab] = useState<'overview' | 'farmers' | 'report'>('overview');

  // Load district analytics
  useEffect(() => {
    async function loadData() {
      setIsLoading(true);
      try {
        const [sumRes, fieldsRes] = await Promise.all([
          getDistrictSummary(district),
          getDistrictFields(district)
        ]);
        setSummary(sumRes);
        setFields(fieldsRes);
      } catch (err) {
        console.error('Failed to load dashboard data:', err);
      } finally {
        setIsLoading(false);
      }
    }
    loadData();
  }, [district]);

  // Log out handler
  const handleLogout = () => {
    router.push('/');
  };

  return (
    <main className="min-h-screen bg-[#f8f9ff] flex flex-col md:flex-row">
      
      {/* ─── Sidebar Navigation — w-64, Delta Green ───────────────────────── */}
      <aside className="w-full md:w-64 bg-primary text-white flex flex-col no-print border-r border-primary-container/20">
        
        {/* Sidebar Brand Header */}
        <div className="p-6 border-b border-primary-container/10 flex items-center space-x-3.5">
          <div className="w-10 h-10 bg-primary-container rounded-xl flex items-center justify-center shadow-lg shadow-black/10">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" className="w-5 h-5 text-white">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 3v18m9-9H3m12-9l-3 3-3-3m6 12l-3-3-3 3" />
            </svg>
          </div>
          <div>
            <h2 className="text-xl font-black tracking-tight text-white leading-none">আকাশি</h2>
            <span className="text-[10px] text-emerald-400 font-semibold uppercase tracking-wider">Crop Monitor</span>
          </div>
        </div>

        {/* Sidebar Links */}
        <nav className="flex-1 p-4 space-y-2.5">
          <button
            onClick={() => setNavTab('overview')}
            className={`w-full px-4 py-3 rounded-xl text-left text-sm font-bold flex items-center space-x-3 transition-all active:scale-[0.98] ${
              navTab === 'overview' 
                ? 'bg-primary-container text-white shadow-md shadow-black/5' 
                : 'hover:bg-primary-container/20 text-emerald-200 hover:text-white'
            }`}
          >
            <span className="text-base">📊</span>
            <span>ড্যাশবোর্ড সামারি</span>
          </button>

          <button
            onClick={() => setNavTab('farmers')}
            className={`w-full px-4 py-3 rounded-xl text-left text-sm font-bold flex items-center space-x-3 transition-all active:scale-[0.98] ${
              navTab === 'farmers'
                ? 'bg-primary-container text-white shadow-md'
                : 'hover:bg-primary-container/20 text-emerald-200 hover:text-white'
            }`}
          >
            <span className="text-base">🌾</span>
            <span>নিবন্ধিত কৃষক তালিকা</span>
          </button>

          <button
            onClick={() => setNavTab('report')}
            className={`w-full px-4 py-3 rounded-xl text-left text-sm font-bold flex items-center space-x-3 transition-all active:scale-[0.98] ${
              navTab === 'report'
                ? 'bg-primary-container text-white shadow-md'
                : 'hover:bg-primary-container/20 text-emerald-200 hover:text-white'
            }`}
          >
            <span className="text-base">📄</span>
            <span>প্রতিবেদন ও এক্সপোর্ট</span>
          </button>
        </nav>

        {/* Sidebar Profile / Logout */}
        <div className="p-4 border-t border-primary-container/10 bg-primary-container/10">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center space-x-2.5">
              <div className="w-8 h-8 rounded-full bg-secondary-container flex items-center justify-center text-xs font-black text-on-secondary-container">
                AO
              </div>
              <div className="text-xs">
                <div className="font-bold text-white leading-none mb-0.5">কৃষি অফিসার</div>
                <div className="text-[10px] text-emerald-400 font-semibold">Tangail DAE</div>
              </div>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="w-full py-2 bg-error text-white text-xs font-bold rounded-lg hover:bg-opacity-90 transition-all flex items-center justify-center space-x-1.5"
          >
            <span>🚪</span>
            <span>লগআউট করুন</span>
          </button>
        </div>
      </aside>

      {/* ─── Main Contents Panel ─────────────────────────────────────────── */}
      <section className="flex-1 flex flex-col min-h-screen overflow-y-auto">
        
        {/* Top Operational Header */}
        <header className="p-6 bg-white border-b border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-4 no-print">
          <div>
            <h1 className="text-2xl font-black text-slate-800 tracking-tight leading-none mb-1">
              কৃষি উন্নয়ন সারসংক্ষেপ
            </h1>
            <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
              ডিভিশনাল স্যাটেলাইট ট্র্যাকিং পোর্টাল
            </p>
          </div>

          {/* District selector drop */}
          <div className="flex items-center space-x-3.5">
            <label className="text-xs font-bold text-slate-500">জেলা নির্বাচন:</label>
            <select
              className="px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-primary/20"
              value={district}
              onChange={(e) => setDistrict(e.target.value)}
            >
              <option value="Tangail">Tangail (টাঙ্গাইল)</option>
              <option value="Mymensingh">Mymensingh (ময়মনসিংহ)</option>
              <option value="Dhaka">Dhaka (ঢাকা)</option>
              <option value="Comilla">Comilla (কুমিল্লা)</option>
            </select>
          </div>
        </header>

        {/* Dynamic Nav View Content */}
        <div className="p-6 space-y-6 flex-1">
          {isLoading ? (
            <div className="h-96 flex items-center justify-center">
              <span className="w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin"></span>
            </div>
          ) : (
            <>
              {/* Tab 1: Overview Summary */}
              {navTab === 'overview' && (
                <div className="space-y-6 animate-fade-in">
                  
                  {/* Summary Metric Cards Grid */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
                    <StatsCard 
                      title="মোট নিবন্ধিত কৃষক"
                      value={summary?.farmer_count || 0}
                      icon={<span>👥</span>}
                      accentColor="primary"
                    />
                    <StatsCard 
                      title="মোট আবাদি জমি"
                      value={summary?.field_count || 0}
                      icon={<span>🗺️</span>}
                      accentColor="secondary"
                    />
                    <StatsCard 
                      title="গড় শস্য NDVI"
                      value={summary?.avg_ndvi || 0}
                      icon={<span>📈</span>}
                      accentColor="tertiary"
                      description="সুস্থ ফসল নির্দেশক"
                    />
                    <StatsCard 
                      title="ঝুঁকিপূর্ণ জমি (লাল)"
                      value={summary?.red_fields || 0}
                      icon={<span>⚠️</span>}
                      accentColor="error"
                      description="জরুরি সেচ/সার প্রয়োজন"
                    />
                  </div>

                  {/* Operational Map & Upazila Stats split grid */}
                  <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Leaflet Map Overlay */}
                    <div className="lg:col-span-2 h-[450px] flex flex-col">
                      <h3 className="text-lg font-bold text-slate-800 mb-3.5">জেলা শস্য স্বাস্থ্য স্যাটেলাইট মানচিত্র</h3>
                      <div className="flex-1">
                        <DistrictMap fields={fields} />
                      </div>
                    </div>

                    {/* Upazila Health Leaderboard */}
                    <div className="bg-white rounded-2xl shadow-md border border-slate-100 p-5 flex flex-col">
                      <h3 className="text-lg font-bold text-slate-800 mb-4">উপজেলা ভিত্তিক স্বাস্থ্যাবস্থা</h3>
                      
                      <div className="flex-1 divide-y divide-slate-100 text-xs">
                        <div className="py-2.5 flex justify-between font-bold text-slate-400 uppercase">
                          <span>উপজেলা</span>
                          <span className="text-right">ঝুঁকিপূর্ণ / মোট জমি</span>
                        </div>

                        {/* Seeded mockup list of upazila stats */}
                        {[
                          { name: 'টাঙ্গাইল সদর', stressed: 2, total: 12, ratio: 16 },
                          { name: 'মির্জাপুর', stressed: 3, total: 8, ratio: 37 },
                          { name: 'কালিহাতি', stressed: 1, total: 5, ratio: 20 },
                          { name: 'মধুপুর', stressed: 0, total: 3, ratio: 0 }
                        ].map((upazila) => (
                          <div key={upazila.name} className="py-3.5 flex items-center justify-between">
                            <div>
                              <div className="font-bold text-slate-700">{upazila.name}</div>
                              <div className="text-[10px] text-slate-400 font-medium">DAE Extension Unit</div>
                            </div>
                            
                            <div className="text-right">
                              <div className="font-extrabold text-slate-800">{upazila.stressed} / {upazila.total}</div>
                              <span className={`text-[10px] font-bold ${
                                upazila.ratio > 30 ? 'text-error' : (upazila.ratio > 0 ? 'text-amber-500' : 'text-emerald-500')
                              }`}>
                                {upazila.ratio}% ঝুঁকিপূর্ণ
                              </span>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>

                  {/* Searchable Fields Grid */}
                  <HealthTable fields={fields} />
                </div>
              )}

              {/* Tab 2: Farmers list only */}
              {navTab === 'farmers' && (
                <div className="animate-fade-in">
                  <HealthTable fields={fields} />
                </div>
              )}

              {/* Tab 3: Government PDF export summaries */}
              {navTab === 'report' && (
                <div className="bg-white rounded-2xl shadow-md border border-slate-100 p-8 max-w-4xl mx-auto animate-fade-in print-card">
                  <div className="flex justify-between items-start border-b border-slate-100 pb-6 mb-6">
                    <div>
                      <h2 className="text-2xl font-black text-slate-800 tracking-tight leading-none mb-1">
                        শস্য স্বাস্থ্য সংক্ষিপ্ত প্রতিবেদন ({district})
                      </h2>
                      <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                        কৃষি সম্প্রসারণ অধিদপ্তর (DAE) | বাংলাদেশ
                      </p>
                    </div>
                    <button
                      onClick={() => window.print()}
                      className="px-5 py-2.5 bg-primary text-white text-xs font-bold rounded-xl shadow-md shadow-primary/20 hover:bg-opacity-95 no-print transition-all active:scale-[0.98]"
                    >
                      🖨️ প্রতিবেদন প্রিন্ট করুন
                    </button>
                  </div>

                  <div className="space-y-6">
                    {/* Summary stats */}
                    <div className="grid grid-cols-3 gap-4 p-5 bg-slate-50 border border-slate-100 rounded-xl text-center">
                      <div>
                        <div className="text-2xl font-black text-slate-800">{summary?.farmer_count}</div>
                        <div className="text-[10px] font-bold text-slate-400 uppercase">মোট কৃষক</div>
                      </div>
                      <div>
                        <div className="text-2xl font-black text-slate-800">{summary?.field_count}</div>
                        <div className="text-[10px] font-bold text-slate-400 uppercase">মোট জমি</div>
                      </div>
                      <div>
                        <div className="text-2xl font-black text-slate-800">{summary?.avg_ndvi}</div>
                        <div className="text-[10px] font-bold text-slate-400 uppercase">গড় NDVI মান</div>
                      </div>
                    </div>

                    {/* Breakdown table */}
                    <div className="space-y-3">
                      <h4 className="text-sm font-bold text-slate-700">উপজেলা ভিত্তিক স্বাস্থ্যের বিস্তারিত তালিকা:</h4>
                      
                      <div className="border border-slate-100 rounded-xl overflow-hidden text-xs">
                        <div className="grid grid-cols-4 bg-slate-50 border-b border-slate-100 p-3 font-bold text-slate-500 text-center">
                          <span className="text-left">উপজেলা</span>
                          <span>সবুজ জমি (সুস্থ)</span>
                          <span>হলুদ জমি (সতর্কতা)</span>
                          <span className="text-right">লাল জমি (জরুরি)</span>
                        </div>
                        {[
                          { name: 'টাঙ্গাইল সদর', green: 10, yellow: 0, red: 2 },
                          { name: 'মির্জাপুর', green: 5, yellow: 0, red: 3 },
                          { name: 'কালিহাতি', green: 4, yellow: 0, red: 1 }
                        ].map((row) => (
                          <div key={row.name} className="grid grid-cols-4 border-b border-slate-100 p-4 text-slate-700 text-center font-medium">
                            <span className="text-left font-bold text-slate-800">{row.name}</span>
                            <span className="text-emerald-600">{row.green}</span>
                            <span className="text-amber-600">{row.yellow}</span>
                            <span className="text-right text-error font-bold">{row.red}</span>
                          </div>
                        ))}
                      </div>
                    </div>

                    <div className="pt-6 border-t border-slate-100 text-center text-[10px] font-semibold text-slate-400 space-y-1">
                      <div>প্রতিবেদন তৈরির তারিখ: {new Date().toLocaleDateString('bn-BD', { day: 'numeric', month: 'long', year: 'numeric' })}</div>
                      <div>ডকুমেন্ট আইডি: DAE-AKASHI-{district.toUpperCase()}-{new Date().getFullYear()}</div>
                    </div>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </section>

    </main>
  );
}
