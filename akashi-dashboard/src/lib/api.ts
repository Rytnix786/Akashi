/**
 * Akashi — Government Analytics API client
 * ========================================
 * Handles REST requests to the FastAPI backend gov endpoints.
 * Includes complete mock fallbacks to guarantee a fully interactive UI
 * when backend database views are not yet generated in Supabase.
 * 
 * Reference: Akashi MVP Spec v1.0, Section 7
 */

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000';

export interface DistrictSummary {
  district: string;
  farmer_count: number;
  field_count: number;
  green_fields: number;
  yellow_fields: number;
  red_fields: number;
  avg_ndvi: number | null;
  last_updated: string;
}

export interface FieldHealthData {
  id: string;
  farmer_name: string;
  farmer_phone: string;
  field_name: string;
  crop_type: string;
  area_acres: number;
  area_bigha: number;
  upazila: string;
  health_status: 'green' | 'yellow' | 'red' | 'unknown';
  ndvi_mean: number | null;
  reading_date: string;
}

export interface UpazilaBreakdown {
  upazila: string;
  field_count: number;
  stressed_fields: number;
  green_fields: number;
  yellow_fields: number;
  red_fields: number;
}

export interface DistrictReport {
  district: string;
  generated_at: string;
  summary: DistrictSummary;
  upazila_breakdown: UpazilaBreakdown[];
}

// ─── Direct Fallbacks ────────────────────────────────────────────────────────


// ─── API Client Methods ──────────────────────────────────────────────────────

export async function getDistrictSummary(district: string): Promise<DistrictSummary> {
  const response = await fetch(`${API_BASE_URL}/gov/districts/${district}/health`, {
    next: { revalidate: 300 } // Cache and revalidate every 5 minutes (matching NDVI cycle)
  });
  if (!response.ok) throw new Error('API summary status not 200');
  return await response.json();
}

export async function getDistrictFields(district: string): Promise<FieldHealthData[]> {
  const response = await fetch(`${API_BASE_URL}/gov/districts/${district}/fields`, {
    next: { revalidate: 300 }
  });
  if (!response.ok) throw new Error('API fields list status not 200');
  return await response.json();
}

export async function getDistrictReport(district: string): Promise<DistrictReport> {
  const response = await fetch(`${API_BASE_URL}/gov/districts/${district}/report`, {
    next: { revalidate: 300 }
  });
  if (!response.ok) throw new Error('API report compiled status not 200');
  return await response.json();
}
