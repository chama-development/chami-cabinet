import { useEffect, useState } from "react";
import { Activity } from "lucide-react";
import { statusApi, type StatusResponse } from "@/api/status";
import { Flag } from "@/components/Flag";
import { useT } from "@/i18n/I18nContext";

// Компактный блок статуса серверов для кабинета — те же данные, что на публичной
// странице /status. Только «работает / недоступен»: пинг из браузера до VPN-ноды
// получался в 2–4 раза выше реального и расходился с приложением. Автообновление каждые 30 с.
export function ServerStatusCard() {
  const t = useT();
  const [data, setData] = useState<StatusResponse | null>(null);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    let alive = true;
    const load = () =>
      statusApi
        .myServers()
        .then((d) => { if (alive) { setData(d); setLoaded(true); } })
        .catch(() => { if (alive) setLoaded(true); });
    load();
    const id = setInterval(load, 30000);
    return () => { alive = false; clearInterval(id); };
  }, []);

  // Пока грузится или нет данных о нодах — блок не показываем (не мозолим глаза).
  if (!loaded || !data || data.nodes.length === 0) return null;

  return (
    <div className="surface p-5">
      {/* Общей надписи «все работают / часть недоступна» нет: состояние каждого
          сервера видно по точке в его строке, сводка — «N / M онлайн». */}
      <div className="mb-4 flex items-center gap-3">
        <div className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-accent-subtle text-accent">
            <Activity className="h-4 w-4" />
          </div>
          <div>
            <p className="text-sm font-semibold text-fg">{t("status.title")}</p>
            <p className="text-xs text-fg-muted">
              {data.online} / {data.total} {t("status.online")}
            </p>
          </div>
        </div>
      </div>

      <div className="space-y-1.5">
        {data.nodes.map((n, i) => (
          <div key={i} className="flex items-center gap-2 rounded-xl bg-bg-subtle px-3 py-2.5">
            {n.country_code && <Flag code={n.country_code} className="h-4 w-6" />}
            <span className="min-w-0 truncate text-sm font-medium text-fg">{n.name}</span>
            <span className="flex-1" />
            <span className={`flex items-center gap-1.5 text-xs font-medium ${n.online ? "text-success" : "text-danger"}`}>
              <span className={`h-2 w-2 rounded-full ${n.online ? "bg-success" : "bg-danger"}`} />
              {n.online ? t("info.online") : t("info.offline")}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
