import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  try {
    const { email, password } = await request.json();
    
    // Call backend
    const apiRes = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'}/gov/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email, password }),
    });

    const data = await apiRes.json();
    if (!apiRes.ok || data.status !== 'success') {
      return NextResponse.json(
        { error: data.detail || 'ভুল ইমেল বা পাসওয়ার্ড।' },
        { status: apiRes.status || 401 }
      );
    }

    // Set cookie
    const response = NextResponse.json({ success: true, user: data.user });
    
    // Set httpOnly cookie
    response.cookies.set('gov_session', data.access_token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 8, // 8 hours
    });

    // Also set a non-httpOnly cookie for district and email to use in UI if needed
    response.cookies.set('gov_email', data.user.email, { path: '/' });
    response.cookies.set('gov_district', data.user.district || 'National', { path: '/' });
    response.cookies.set('gov_role', data.user.role, { path: '/' });

    return response;
  } catch (err: any) {
    console.error('Login route handler error:', err);
    return NextResponse.json({ error: 'সার্ভারের সাথে সংযোগ করা যাচ্ছে না।' }, { status: 500 });
  }
}
