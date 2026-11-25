import type { Metadata } from 'next';
import { Cairo } from 'next/font/google';

const cairo = Cairo({ subsets: ['arabic', 'latin'], weight: ['400', '600', '700', '800'] });

export const metadata: Metadata = {
  title: 'لوحة تحكم بلدنا (Baladna Admin)',
  description: 'إدارة الإعلانات والمستخدمين والبلاغات لمنصة بلدنا',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl">
      <body className={`${cairo.className} bg-[#FAF7F2] text-slate-900 min-h-screen`}>
        {children}
      </body>
    </html>
  );
}
