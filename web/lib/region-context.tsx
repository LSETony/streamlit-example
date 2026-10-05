"use client";
import { createContext, useContext, useMemo } from "react";
import { money } from "@/lib/format";
import { regionInfo, type Region, type RegionInfo } from "@/lib/region";

interface RegionValue extends RegionInfo {
  region: Region;
  /** сумма в сотых долях валюты зала → «3 000 ₽» / «AED 450» */
  money: (minor: number | null | undefined) => string;
}

const Ctx = createContext<RegionValue | null>(null);

function build(region: Region): RegionValue {
  const info = regionInfo(region);
  return { ...info, region, money: (v) => money(v, info.currency) };
}

/** Регион зала для клиентских компонентов кабинета: валюта, телефонный код, способы оплаты */
export function RegionProvider({ region, children }: { region: Region; children: React.ReactNode }) {
  const value = useMemo(() => build(region), [region]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useRegion(): RegionValue {
  return useContext(Ctx) ?? build("RU");
}
