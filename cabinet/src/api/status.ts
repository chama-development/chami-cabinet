import { api } from "./client";

export interface UptimeDay {
  date: string; // YYYY-MM-DD
  uptime: number; // % за день
}

export interface StatusNode {
  name: string;
  country_code: string;
  online: boolean;
  uptime_30d?: number | null; // аптайм % за 30 дней (из node_health)
  history?: UptimeDay[]; // посуточная история для «свечек»
}

export interface StatusResponse {
  nodes: StatusNode[];
  all_operational: boolean;
  total: number;
  online: number;
  enabled?: boolean; // отдаёт /subscription/servers: включён ли блок в админке
}

// Публичный статус сервиса (без авторизации).
export const statusApi = {
  get: () => api.get<StatusResponse>("/status"),
  // Серверы вошедшего пользователя (привязка по подписке). Адресов нод нет ни там, ни там.
  myServers: () => api.get<StatusResponse>("/subscription/servers"),
};
