import { Sidebar, MobileNav } from "@/components/app/sidebar";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen">
      <Sidebar />
      <MobileNav />
      <main className="md:pl-60">
        <div className="mx-auto max-w-6xl px-4 pb-16 pt-6 md:px-10 md:pt-10">
          {children}
        </div>
      </main>
    </div>
  );
}