import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = {title:'SHIFT — Your social intelligence',description:'Research, create, schedule and grow with SHIFT.'};
export default function RootLayout({children}:{children:React.ReactNode}) {return <html lang="en"><body>{children}</body></html>}
