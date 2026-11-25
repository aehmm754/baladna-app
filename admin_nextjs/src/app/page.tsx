'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

interface AdRow {
  id: string;
  title: string;
  governorate: string;
  price: number;
  currency: string;
  status: string;
  is_featured: boolean;
}

export default function AdminDashboardPage() {
  const [ads, setAds] = useState<AdRow[]>([]);
  const [loading, setLoading] = useState(true);

  async function loadAds() {
    setLoading(true);
    const { data } = await supabase
      .from('ads')
      .select('id, title, governorate, price, currency, status, is_featured')
      .order('created_at', { ascending: false })
      .limit(50);
    setAds((data as AdRow[]) || []);
    setLoading(false);
  }

  useEffect(() => { loadAds(); }, []);

  async function updateStatus(id: string, status: string) {
    await supabase.from('ads').update({ status }).eq('id', id);
    loadAds();
  }

  async function toggleFeatured(id: string, current: boolean) {
    await supabase.from('ads').update({ is_featured: !current }).eq('id', id);
    loadAds();
  }

  return (
    <main className="max-w-6xl mx-auto p-6 space-y-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-extrabold text-[#0F6A5B]">لوحة تحكم بلدنا</h1>
          <p className="text-sm text-slate-500">مراجعة الإعلانات، التمييز، وإدارة المحتوى</p>
        </div>
        <button onClick={loadAds} className="px-4 py-2 rounded-xl bg-[#0F6A5B] text-white text-sm font-bold">
          تحديث البيانات
        </button>
      </header>

      <section className="bg-white rounded-2xl border border-[#EAE3D9] overflow-hidden">
        <table className="w-full text-right text-sm">
          <thead className="bg-slate-50 text-slate-600">
            <tr>
              <th className="p-3">العنوان</th>
              <th className="p-3">المحافظة</th>
              <th className="p-3">السعر</th>
              <th className="p-3">الحالة</th>
              <th className="p-3">الإجراءات</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {loading ? (
              <tr><td colSpan={5} className="p-6 text-center text-slate-400">جارٍ التحميل...</td></tr>
            ) : ads.map((ad) => (
              <tr key={ad.id}>
                <td className="p-3 font-bold">{ad.title}</td>
                <td className="p-3">{ad.governorate}</td>
                <td className="p-3 font-bold text-[#0F6A5B]">{ad.price} {ad.currency}</td>
                <td className="p-3">{ad.status}</td>
                <td className="p-3 flex gap-2">
                  <button onClick={() => updateStatus(ad.id, 'approved')} className="px-3 py-1 rounded-lg bg-emerald-600 text-white text-xs font-bold">موافقة</button>
                  <button onClick={() => toggleFeatured(ad.id, ad.is_featured)} className="px-3 py-1 rounded-lg bg-amber-500 text-white text-xs font-bold">
                    {ad.is_featured ? 'إلغاء التمييز' : 'تمييز'}
                  </button>
                  <button onClick={() => updateStatus(ad.id, 'rejected')} className="px-3 py-1 rounded-lg bg-rose-600 text-white text-xs font-bold">رفض</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </main>
  );
}
