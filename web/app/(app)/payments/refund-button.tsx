"use client";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { RefundDialog } from "../clients/[id]/refund-dialog";
import type { PaymentListRow } from "./page";

export function RefundButton({ payment }: { payment: PaymentListRow }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  return (
    <>
      <Button size="sm" variant="ghost" onClick={() => setOpen(true)}><RotateCcw /> Возврат</Button>
      {open ? <RefundDialog payment={payment} clientId={payment.client_id ?? undefined} onClose={() => { setOpen(false); router.refresh(); }} /> : null}
    </>
  );
}
