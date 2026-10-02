"use client";
import { cloneElement, createContext, Fragment, isValidElement, useContext, useMemo } from "react";
import { makeT, type Locale, type T } from "./core";

const I18nContext = createContext<T>(makeT("ru"));

export function I18nProvider({ locale, children }: { locale: Locale; children: React.ReactNode }) {
  const t = useMemo(() => makeT(locale), [locale]);
  return <I18nContext.Provider value={t}>{children}</I18nContext.Provider>;
}

export function useT(): T {
  return useContext(I18nContext);
}

/**
 * Перевод текста внутри элементов: строки переводятся (с сохранением пробелов вокруг),
 * у единственного дочернего элемента (Button asChild → Link) переводится его текст.
 * Нужен базовым компонентам (кнопки, подписи, заголовки), чтобы вызывающий код писал текст как обычно.
 */
export function translateNode(t: T, node: React.ReactNode, deep = true): React.ReactNode {
  if (typeof node === "string") {
    const trimmed = node.trim();
    if (!trimmed) return node;
    const lead = node.slice(0, node.indexOf(trimmed));
    const tail = node.slice(node.indexOf(trimmed) + trimmed.length);
    return lead + t(trimmed) + tail;
  }
  if (Array.isArray(node)) return node.map((n, i) => <Fragment key={i}>{translateNode(t, n, deep)}</Fragment>);
  if (deep && isValidElement<{ children?: React.ReactNode }>(node) && node.props.children !== undefined) {
    return cloneElement(node, undefined, translateNode(t, node.props.children, false));
  }
  return node;
}

export function useTx() {
  const t = useT();
  return (node: React.ReactNode, deep = true) => translateNode(t, node, deep);
}
