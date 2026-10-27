"""Блок «Статус сервиса»: адреса нод и хостов не уходят в кабинет никому.

ЧТО БЫЛО. `/subscription/servers` отдавал `host` — адрес хоста из панели — всем
вошедшим с подпиской и сотрудникам: кабинет пинговал по нему ноды из браузера.
Пинг убрали (цифры выходили в 2–4 раза выше, чем в VPN-приложении), а адреса
продолжали раздаваться каждому. По адресу ноду находят и блокируют, поэтому в
ответе его быть не должно ни в одной ветке: сотрудник, активная подписка,
кончившаяся подписка, новый пользователь.

Запуск — внутри образа бота, как остальные тесты рядом.
"""

import importlib
from types import SimpleNamespace

import pytest

importlib.import_module("src.web.endpoints.public")
mod = importlib.import_module("src.web.endpoints.public.service_status")

from src.core.enums import Role  # noqa: E402

SECRET = "de-node.secret.example"
# Снимаем dishka-обёртку: вызываем исходную корутину с подделками.
my_servers = mod.my_servers.__dishka_orig_func__


def _sdk():
    node = SimpleNamespace(
        uuid="n1",
        name="Germany node",
        country_code="DE",
        is_connected=True,
        is_disabled=False,
        config_profile=SimpleNamespace(active_inbounds=[SimpleNamespace(uuid="in1")]),
    )
    real = SimpleNamespace(
        remark="🇩🇪 Германия", address=SECRET, inbound_uuid="in1",
        is_hidden=False, is_disabled=False, excluded_internal_squads=[],
    )
    stub = SimpleNamespace(
        remark="Подписка закончилась", address=SECRET, inbound_uuid="in1",
        is_hidden=False, is_disabled=False, excluded_internal_squads=[],
    )

    async def nodes():
        return [node]

    async def hosts():
        return [real, stub]

    return SimpleNamespace(
        nodes=SimpleNamespace(get_all_nodes=nodes),
        hosts=SimpleNamespace(get_all_hosts=hosts),
    )


class _Dao:
    async def get_current(self, user_id):
        return None


@pytest.fixture(autouse=True)
def _config(monkeypatch):
    monkeypatch.setattr(
        mod,
        "load_config",
        lambda: {
            "enabled": True,
            "bind_to_subscription": False,
            "guest_visible": True,
            "visible_nodes": [],
            "service_keywords": ["закончилась"],
        },
    )


def _assert_no_address(resp: dict) -> None:
    assert resp["nodes"], "ответ пустой — тест ничего не проверил"
    for item in resp["nodes"]:
        assert "host" not in item
        assert SECRET not in repr(item)


@pytest.mark.parametrize("state", ["staff", "active", "expired", "new"])
async def test_no_address_in_any_branch(monkeypatch, state):
    role = Role.ADMIN if state == "staff" else Role.USER
    user = SimpleNamespace(id=1, role=role)

    async def sub_state(_session, _uid):
        return {"active": (True, True), "expired": (True, False), "new": (False, False)}.get(state, (False, False))

    monkeypatch.setattr(mod, "_current_sub_state", sub_state)
    resp = await my_servers(
        user=user,
        subscription_dao=_Dao(),
        remnawave=SimpleNamespace(sdk=_sdk()),
        session=None,
    )
    _assert_no_address(resp)
