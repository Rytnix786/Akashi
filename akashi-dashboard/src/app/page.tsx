'use client';

/**
 * Akashi — Government Analytics Login Screen
 * ==========================================
 * Standard auth portal featuring operational branding and Delta-Green aesthetics.
 * 
 * Reference: Akashi MVP Spec v1.0, Section 7.1
 */

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    try {
      const res = await fetch('/api/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || 'ভুল ইমেল বা পাসওয়ার্ড। অনুগ্রহ করে পুনরায় চেষ্টা করুন।');
      }

      router.push('/dashboard');
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'সার্ভারের সাথে সংযোগ করা যাচ্ছে না।';
      setError(errorMsg);
      setIsLoading(false);
    }
  };

  return (
    <main className="min-h-screen flex items-center justify-center px-4 bg-gradient-to-tr from-surface-container via-surface to-background animate-fade-in">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl border border-surface-dim/40 overflow-hidden p-8">
        
        {/* Branding Header */}
        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 bg-primary-container rounded-2xl flex items-center justify-center shadow-lg shadow-primary/10 mb-4">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" className="w-8 h-8 text-white">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 3v18m9-9H3m12-9l-3 3-3-3m6 12l-3-3-3 3" />
            </svg>
          </div>
          <h1 className="text-3xl font-extrabold text-primary mb-1 tracking-tight">আকাশি</h1>
          <p className="text-sm font-medium text-slate-500">সরকারি শস্য পর্যবেক্ষণ ড্যাশবোর্ড</p>
        </div>

        {/* Auth Form */}
        <form onSubmit={handleLogin} className="space-y-5">
          {error && (
            <div className="p-3 bg-red-50 border border-red-200 text-error text-xs rounded-lg font-medium">
              {error}
            </div>
          )}

          <div>
            <label className="block text-xs font-semibold text-slate-700 mb-1.5" htmlFor="email">
              ইমেল অ্যাড্রেস
            </label>
            <input
              id="email"
              type="text"
              required
              className="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all placeholder:text-slate-400"
              placeholder="officer@dae.gov.bd"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>

          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="block text-xs font-semibold text-slate-700" htmlFor="password">
                পাসওয়ার্ড
              </label>
              <a href="#" className="text-xs font-semibold text-secondary hover:underline">
                পাসওয়ার্ড ভুলে গেছেন?
              </a>
            </div>
            <input
              id="password"
              type="password"
              required
              className="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all placeholder:text-slate-400"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full py-3 bg-primary text-white text-sm font-semibold rounded-xl hover:bg-opacity-95 shadow-md shadow-primary/20 transition-all active:scale-[0.99] disabled:bg-slate-300 disabled:shadow-none flex items-center justify-center"
          >
            {isLoading ? (
              <span className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
            ) : (
              'লগইন করুন'
            )}
          </button>
        </form>

        <div className="mt-8 pt-6 border-t border-slate-100 text-center">
          <p className="text-xs font-medium text-slate-400">
            © ২০২৬ কৃষি সম্প্রসারণ অধিদপ্তর (DAE) | গণপ্রজাতন্ত্রী বাংলাদেশ সরকার
          </p>
        </div>
      </div>
    </main>
  );
}
