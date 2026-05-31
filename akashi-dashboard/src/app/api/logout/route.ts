import { NextResponse } from 'next/server';

export async function POST() {
  const response = NextResponse.json({ success: true });
  response.cookies.delete('gov_session');
  response.cookies.delete('gov_email');
  response.cookies.delete('gov_district');
  response.cookies.delete('gov_role');
  return response;
}
