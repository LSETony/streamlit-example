import { MemberApp } from "./member-app";

export default async function MemberPage({ searchParams }: PageProps<"/m">) {
  const sp = await searchParams;
  const gym = typeof sp.gym === "string" ? sp.gym : null;
  return <MemberApp joinGym={gym} />;
}
