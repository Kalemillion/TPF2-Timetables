function data()
return {
	-- The 13 vanilla langages + 3 modded ones, added because they exist on Steam Workshop
	-- Aside from en & fr, they're AI translated, feel free to correct

	-- Western Europe
	en = {
		["arr_i18n"] = "Arr: ",
		["arrival_i18n"] = "Arrival",
		["dep_i18n"] = "Dep: ",
		["departure_i18n"] = "Departure",
		["unbunch_time_i18n"] = "Unbunch Time",
		["unbunch_i18n"] = "Unbunch",
		["auto_unbunch_i18n"] = "Auto Unbunch",
		["timetable_i18n"] = "Timetable",
		["timetables_i18n"] = "Timetables",
		["line_i18n"] = "Line",
		["lines_i18n"] = "Lines",
		["time_min_i18n"] = "min",
		["time_sec_i18n"] = "sec",
		["stations_i18n"] = "Stations",
		["frequency_i18n"] = "Frequency",
		["journey_time_i18n"] = "Journey Time",
		["arr_dep_i18n"] = "Arrival/Departure",
		["no_timetable_i18n"] = "No Timetable",
		["all_i18n"] = "All",
		["add_i18n"] = "Add",
		["none_i18n"] = "None",
		["force_departure_i18n"] = "Force departure",
		["min_wait_enabled_i18n"] = "Min. wait enabled",
		["max_wait_enabled_i18n"] = "Max. wait enabled",
		["margin_time_i18n"] = "Margin Time",
		["tooltip_i18n"] = [[
			You can add timetable constraints to each station.
			When a train arrives at the station it will try to
			keep the constraints. The following constraints are available:
			- Arrival/Departure: Set multiple Arr/Dep times and the train chooses the closest arrival time
			- Unbunch: Set a time and vehicles will only depart the station in the given interval
		]],
		["modname_name"] = "Timetables",
		["modname_desc"] = "This mod adds timetables to the game",
	},
	es = {
		["arr_i18n"] = "Lle: ",
		["arrival_i18n"] = "Llegada",
		["dep_i18n"] = "Sal: ",
		["departure_i18n"] = "Salida",
		["unbunch_time_i18n"] = "Tiempo de distanciamiento",
		["unbunch_i18n"] = "Distanciamiento",
		["auto_unbunch_i18n"] = "Distanciamiento automático",
		["timetable_i18n"] = "Horario",
		["timetables_i18n"] = "Horarios",
		["line_i18n"] = "Línea",
		["lines_i18n"] = "Líneas",
		["time_min_i18n"] = "min",
		["time_sec_i18n"] = "seg",
		["stations_i18n"] = "Estaciones",
		["frequency_i18n"] = "Frecuencia",
		["journey_time_i18n"] = "Tiempo de viaje",
		["arr_dep_i18n"] = "Llegada/Salida",
		["no_timetable_i18n"] = "Sin horario",
		["all_i18n"] = "Todos",
		["add_i18n"] = "Añadir",
		["none_i18n"] = "Ninguno",
		["force_departure_i18n"] = "Forzar salida",
		["min_wait_enabled_i18n"] = "Espera mín. habilitada",
		["max_wait_enabled_i18n"] = "Espera máx. habilitada",
		["margin_time_i18n"] = "Margen de tiempo",
		["tooltip_i18n"] = [[
			Puede añadir restricciones de horario a cada estación.
			Cuando un tren llega a la estación intentará mantener
			las restricciones. Las restricciones disponibles son:
			- Llegada/Salida: Establezca múltiples horarios de llegada/salida y el tren elegirá el más cercano
			- Distanciamiento: Establezca un intervalo de tiempo para que los vehículos salgan en ese intervalo
		]],
		["modname_name"] = "Horarios",
		["modname_desc"] = "Este mod agrega horarios al juego",
	},
	fr = {
		["arr_i18n"] = "Arr:",
		["arrival_i18n"] = "Arrivée",
		["dep_i18n"] = "Dep:",
		["departure_i18n"] = "Départ",
		["unbunch_time_i18n"] = "Intervalle de régulation",
		["unbunch_i18n"] = "Régulation",
		["auto_unbunch_i18n"] = "Régulation Auto",
		["timetable_i18n"] = "Horaire",
		["timetables_i18n"] = "Horaires",
		["line_i18n"] = "Ligne",
		["lines_i18n"] = "Lignes",
		["time_min_i18n"] = "min",
		["time_sec_i18n"] = "sec",
		["stations_i18n"] = "Gares",
		["frequency_i18n"] = "Fréquence",
		["journey_time_i18n"] = "Temps de trajet",
		["arr_dep_i18n"] = "Arrivée / Départ",
		["no_timetable_i18n"] = "Pas d'horaire",
		["all_i18n"] = "Tout",
		["add_i18n"] = "Ajouter",
		["none_i18n"] = "Aucun",
		["force_departure_i18n"] = "Départ forcé",
		["min_wait_enabled_i18n"] = "Attente min. du jeu",
		["max_wait_enabled_i18n"] = "Attente max. du jeu",
		["margin_time_i18n"] = "Marge",
		["tooltip_i18n"] = [[
			Vous pouvez définir des contraintes horaires spécifiques à chaque arrêt / station.
			Quand le train arrive en gare, il essayera de respecter les contraintes.
			Les contraintes disponibles sont les suivantes :
			- Arrivée/Départ: avec des horaires prédéfinis, le train choisira l'horaire d'arrivée le plus proche.
			- Regulation: Les trains partiront tous les x temps selon un intervalle de temps défini.
		]],
		["modname_name"] = "Fréquence / Horaire",
		["modname_desc"] = "Ce mod ajoute les gestion des horaires et de la fréquence de passage dans le jeu.",
	},
	nl = {
		["arr_i18n"] = "Arr: ",
		["arrival_i18n"] = "Aankomst",
		["dep_i18n"] = "Vert: ",
		["departure_i18n"] = "Vertrek",
		["unbunch_time_i18n"] = "Spreidingstijd",
		["unbunch_i18n"] = "Spreiding",
		["auto_unbunch_i18n"] = "Auto spreiding",
		["timetable_i18n"] = "Dienstregelingen",
		["timetables_i18n"] = "Dienstregelingen",
		["line_i18n"] = "Lijn",
		["lines_i18n"] = "Lijnen",
		["time_min_i18n"] = "min",
		["time_sec_i18n"] = "sec",
		["stations_i18n"] = "Stations",
		["frequency_i18n"] = "Frequentie",
		["journey_time_i18n"] = "Reistijd",
		["arr_dep_i18n"] = "Aankomst/Vertrek",
		["no_timetable_i18n"] = "Geen dienstregeling",
		["all_i18n"] = "Alle",
		["add_i18n"] = "Toevoegen",
		["none_i18n"] = "Geen",
		["force_departure_i18n"] = "Vertrek afdwingen",
		["min_wait_enabled_i18n"] = "Min. wachttijd ingeschakeld",
		["max_wait_enabled_i18n"] = "Max. wachttijd ingeschakeld",
		["margin_time_i18n"] = "Buffertijd",
		["tooltip_i18n"] = [[
			U kunt dienstregelbeperkingen aan elk station toevoegen.
			Wanneer een trein op het station aankomt, probeert deze
			de beperkingen in acht te nemen. De volgende beperkingen zijn beschikbaar:
			- Aankomst/Vertrek: Stel meerdere aankomst-/vertrekijden in en de trein kiest de dichtstbijzijnde
			- Spreiding: Stel een tijd in waarna voertuigen het station met dat interval verlaten
		]],
		["modname_name"] = "Dienstregelingen",
		["modname_desc"] = "Deze mod voegt dienstregelingen toe aan het spel",
	},
	pt_BR = {
		-- in WE Europe cuz' it'd seem lonely in "Others/South America"
		["arr_i18n"] = "Cheg.:",
		["arrival_i18n"] = "Chegada",
		["dep_i18n"] = "Part.:",
		["departure_i18n"] = "Partida",
		["unbunch_time_i18n"] = "Intervalo de espaçamento",
		["unbunch_i18n"] = "Espaçamento",
		["auto_unbunch_i18n"] = "Espaçamento automático",
		["timetable_i18n"] = "Horário",
		["timetables_i18n"] = "Horários",
		["line_i18n"] = "Linha",
		["lines_i18n"] = "Linhas",
		["time_min_i18n"] = "min",
		["time_sec_i18n"] = "s",
		["stations_i18n"] = "Estações",
		["frequency_i18n"] = "Frequência",
		["journey_time_i18n"] = "Tempo de viagem",
		["arr_dep_i18n"] = "Chegada/Partida",
		["no_timetable_i18n"] = "Sem horários",
		["all_i18n"] = "Todos",
		["add_i18n"] = "Adicionar",
		["none_i18n"] = "Nenhum",
		["force_departure_i18n"] = "Forçar partida",
		["min_wait_enabled_i18n"] = "Espera mínima ativada",
		["max_wait_enabled_i18n"] = "Espera máxima ativada",
		["margin_time_i18n"] = "Margem de tempo",
		["tooltip_i18n"] = [[
			Você pode definir restrições de horário para cada estação.
			Quando um trem chega, ele tenta respeitar essas restrições.
			Opções disponíveis:
			- Chegada/Partida: defina vários horários; o trem escolherá o mais próximo
			- Espaçamento: define um intervalo para evitar que os veículos saiam juntos
		]],
		["modname_name"] = "Horários",
		["modname_desc"] = "Este mod adiciona gerenciamento de horários ao jogo.",
	},

	-- Central & Eastern Europe
	cs = {
        ["arr_i18n"] = "Příj: ",
        ["arrival_i18n"] = "Příjezd",
        ["dep_i18n"] = "Odj: ",
        ["departure_i18n"] = "Odjezd",
        ["unbunch_time_i18n"] = "Čas regulace",
        ["unbunch_i18n"] = "Regulace",
        ["auto_unbunch_i18n"] = "Auto regulace",
        ["timetable_i18n"] = "Jízdní řád",
        ["timetables_i18n"] = "Jízdní řády",
        ["line_i18n"] = "Linka",
        ["lines_i18n"] = "Linky",
        ["time_min_i18n"] = "min",
        ["time_sec_i18n"] = "s",
        ["stations_i18n"] = "Stanice",
        ["frequency_i18n"] = "Interval",
        ["journey_time_i18n"] = "Doba jízdy",
        ["arr_dep_i18n"] = "Příjezd/Odjezd",
        ["no_timetable_i18n"] = "Žádný jízdní řád",
        ["all_i18n"] = "Vše",
        ["add_i18n"] = "Přidat",
        ["none_i18n"] = "Žádné",
        ["force_departure_i18n"] = "Vynutit odjezd",
        ["min_wait_enabled_i18n"] = "Min. čekání zapnuto",
        ["max_wait_enabled_i18n"] = "Max. čekání zapnuto",
        ["margin_time_i18n"] = "Časová rezerva",
        ["tooltip_i18n"] = [[
            Pro každou stanici můžete přidat omezení jízdního řádu.
            Jakmile vlak dorazí do stanice, pokusí se tato
            omezení dodržet. K dispozici jsou následující možnosti:
            - Příjezd/Odjezd: Nastavte více časů a vlak si vybere ten nejbližší.
            - Regulace: Nastavte časový interval, ve kterém budou vozidla opouštět stanici.
        ]],
        ["modname_name"] = "Jízdní řády",
        ["modname_desc"] = "Tento mod přidává do hry jízdní řády.",
    },
	de = {
		["arr_i18n"] = "Ank: ",
		["arrival_i18n"] = "Ankunft",
		["dep_i18n"] = "Abf: ",
		["departure_i18n"] = "Abfahrt",
		["unbunch_time_i18n"] = "Regulierungszeit",
		["unbunch_i18n"] = "Regulierung",
		["auto_unbunch_i18n"] = "Auto-Regulierung",
		["timetable_i18n"] = "Fahrplan",
		["timetables_i18n"] = "Fahrpläne",
		["line_i18n"] = "Linie",
		["lines_i18n"] = "Linien",
		["time_min_i18n"] = "min",
		["time_sec_i18n"] = "sek",
		["stations_i18n"] = "Stationen",
		["frequency_i18n"] = "Takt",
		["journey_time_i18n"] = "Reisezeit",
		["arr_dep_i18n"] = "Ankunft/Abfahrt",
		["no_timetable_i18n"] = "Kein Fahrplan",
		["all_i18n"] = "Alle",
		["add_i18n"] = "Hinzufügen",
		["none_i18n"] = "Keine",
		["force_departure_i18n"] = "Abfahrt erzwingen",
		["min_wait_enabled_i18n"] = "Min. Wartezeit aktiviert",
		["max_wait_enabled_i18n"] = "Max. Wartezeit aktiviert",
		["margin_time_i18n"] = "Pufferzeit",
		["tooltip_i18n"] = [[
			Für jede Station können Fahrplanbedingungen gesetzt werden.
			Wenn ein Zug an der Station ankommt, versucht er diese Bedingungen einzuhalten.
			Folgende Bedingungen sind verfügbar:
			- Ankunft/Abfahrt: Mehrere Ankunfts-/Abfahrtszeiten festlegen; der Zug wählt die nächstliegende Ankunftszeit.
			- Regulierung: Ein Intervall festlegen; Fahrzeuge fahren nur in diesem Zeitabstand ab.
		]],
		["modname_name"] = "Takt / Fahrplan",
		["modname_desc"] = "Diese Mod fügt dem Spiel Fahrpläne und Taktsteuerung hinzu.",
	},
	it = {
		["arr_i18n"] = "Arr: ",
		["arrival_i18n"] = "Arrivo",
		["dep_i18n"] = "Part: ",
		["departure_i18n"] = "Partenza",
		["unbunch_time_i18n"] = "Tempo di distanziamento",
		["unbunch_i18n"] = "Distanziamento",
		["auto_unbunch_i18n"] = "Distanziamento Auto",
		["timetable_i18n"] = "Orario",
		["timetables_i18n"] = "Orari",
		["line_i18n"] = "Linea",
		["lines_i18n"] = "Linee",
		["time_min_i18n"] = "min",
		["time_sec_i18n"] = "sec",
		["stations_i18n"] = "Stazioni",
		["frequency_i18n"] = "Frequenza",
		["journey_time_i18n"] = "Tempo di viaggio",
		["arr_dep_i18n"] = "Arrivo/Partenza",
		["no_timetable_i18n"] = "Nessun orario",
		["all_i18n"] = "Tutti",
		["add_i18n"] = "Aggiungi",
		["none_i18n"] = "Nessuno",
		["force_departure_i18n"] = "Forza partenza",
		["min_wait_enabled_i18n"] = "Attesa min. abilitata",
		["max_wait_enabled_i18n"] = "Attesa max. abilitata",
		["margin_time_i18n"] = "Margine di tempo",
		["tooltip_i18n"] = [[
			Puoi aggiungere un orario per ogni stazione.
			Quando un treno arriva alla stazione, questo proverà
			a mantenere l'orario impostato.
			- Arrivo/Partenza: imposta più orari di arrivo/partenza e il treno sceglierà il più vicino
			- Distanziamento: imposta un intervallo affinché i veicoli partano dalla stazione a cadenza regolare
		]],
		["modname_name"] = "Orari",
		["modname_desc"] = "Questa mod aggiunge gli orari al gioco.",
	},
	pl = {
		["arr_i18n"] = "Przyj: ",
		["arrival_i18n"] = "Przyjazd",
		["dep_i18n"] = "Odj: ",
		["departure_i18n"] = "Odjazd",
		["unbunch_time_i18n"] = "Czas regulacji",
		["unbunch_i18n"] = "Regulacja",
		["auto_unbunch_i18n"] = "Regulacja auto",
		["timetable_i18n"] = "Rozkład jazdy",
		["timetables_i18n"] = "Rozkłady jazdy",
		["line_i18n"] = "Linia",
		["lines_i18n"] = "Linie",
		["time_min_i18n"] = "min",
		["time_sec_i18n"] = "sek",
		["stations_i18n"] = "Stacje",
		["frequency_i18n"] = "Częstotliwość",
		["journey_time_i18n"] = "Czas podróży",
		["arr_dep_i18n"] = "Przyjazd/Odjazd",
		["no_timetable_i18n"] = "Brak rozkładu",
		["all_i18n"] = "Wszystko",
		["add_i18n"] = "Dodaj",
		["none_i18n"] = "Brak",
		["force_departure_i18n"] = "Wymuszone odjazdy",
		["min_wait_enabled_i18n"] = "Min. oczekiwanie włączone",
		["max_wait_enabled_i18n"] = "Maks. oczekiwanie włączone",
		["margin_time_i18n"] = "Margines czasu",
		["tooltip_i18n"] = [[
			Można dodawać ograniczenia rozkładu do każdej stacji.
			Kiedy pociąg przyjeżdża na stację, będzie próbował
			zachować te ograniczenia. Dostępne ograniczenia to:
			- Przyjazd/Odjazd: Ustaw wielokrotne czasy przyjazdu/odjazdu a pociąg wybierze najbliższy
			- Regulacja: Ustaw czas, aby pojazdy opuszczały stację w ustalonych interwałach
		]],
		["modname_name"] = "Rozkład jazdy",
		["modname_desc"] = "Ten mod dodaje rozkład jazdy do gry",
	},
	uk = {
        ["arr_i18n"] = "Приб: ",
        ["arrival_i18n"] = "Прибуття",
        ["dep_i18n"] = "Відпр: ",
        ["departure_i18n"] = "Відправлення",
        ["unbunch_time_i18n"] = "Час інтервалу",
        ["unbunch_i18n"] = "Інтервал",
        ["auto_unbunch_i18n"] = "Авто інтервал",
        ["timetable_i18n"] = "Розклад",
        ["timetables_i18n"] = "Розклади",
        ["line_i18n"] = "Лінія",
        ["lines_i18n"] = "Лінії",
        ["time_min_i18n"] = "хв",
        ["time_sec_i18n"] = "сек",
        ["stations_i18n"] = "Станції",
        ["frequency_i18n"] = "Частота",
        ["journey_time_i18n"] = "Час у дорозі",
        ["arr_dep_i18n"] = "Прибуття/Відправлення",
        ["no_timetable_i18n"] = "Немає розкладу",
        ["all_i18n"] = "Все",
        ["add_i18n"] = "Додати",
        ["none_i18n"] = "Немає",
        ["force_departure_i18n"] = "Примусове відправлення",
        ["min_wait_enabled_i18n"] = "Мін. очікування увімкнено",
        ["max_wait_enabled_i18n"] = "Макс. очікування увімкнено",
        ["margin_time_i18n"] = "Запас часу",
        ["tooltip_i18n"] = [[
            Ви можете додати обмеження розкладу для кожної станції.
            Коли поїзд прибуває на станцію, він намагатиметься
            дотримуватися цих обмежень. Доступні наступні варіанти:
            - Прибуття/Відправлення: встановіть кілька часових міток, і поїзд обере найближчу.
            - Інтервал: встановіть час, щоб транспорт залишав станцію з заданим інтервалом.
        ]],
        ["modname_name"] = "Розклади",
        ["modname_desc"] = "Цей мод додає розклади руху в гру.",
    },
	ru = {
		["arr_i18n"] = "Приб.: ",
		["arrival_i18n"] = "Прибытие",
		["dep_i18n"] = "Отпр.: ",
		["departure_i18n"] = "Отправление",
		["unbunch_time_i18n"] = "Время интервала",
		["unbunch_i18n"] = "Интервал",
		["auto_unbunch_i18n"] = "Авто Интервал",
		["timetable_i18n"] = "Расписание",
		["timetables_i18n"] = "Расписания",
		["line_i18n"] = "Линия",
		["lines_i18n"] = "Линии",
		["time_min_i18n"] = "мин.",
		["time_sec_i18n"] = "сек.",
		["stations_i18n"] = "Станции",
		["frequency_i18n"] = "Частота",
		["journey_time_i18n"] = "Время поездки",
		["arr_dep_i18n"] = "Прибытие/Отправление",
		["no_timetable_i18n"] = "Нет расписания",
		["all_i18n"] = "Все",
		["add_i18n"] = "Добавить",
		["none_i18n"] = "Отсутствует",
		["tooltip_i18n"] = [[
			Вы можете отрегулировать расписание для каждой станции.
			По прибытию на станцию, поезд будет стараться следовать расписанию.
			Следующие варианты регулировки доступны:
			- Прибытие/Отправление: установите время прибытия и отправления и поезд выберет ближайшее подходящее время отправления
			- Интервал: настройте время и транспорт будет отправляться со станции согласно выбранному интервалу
		]],
		["modname_name"] = "Расписание",
		["modname_desc"] = "Этот мод добавляет в игру расписание.",
	},

	-- Asia
	ja = {
		["arr_i18n"] = "到: ",
		["arrival_i18n"] = "到着",
		["dep_i18n"] = "発: ",
		["departure_i18n"] = "出発",
		["unbunch_time_i18n"] = "出発間隔",
		["unbunch_i18n"] = "間隔制御",
		["auto_unbunch_i18n"] = "自動間隔制御",
		["timetable_i18n"] = "時刻表",
		["timetables_i18n"] = "時刻表",
		["line_i18n"] = "路線",
		["lines_i18n"] = "路線",
		["time_min_i18n"] = "分",
		["time_sec_i18n"] = "秒",
		["stations_i18n"] = "駅",
		["frequency_i18n"] = "運行頻度",
		["journey_time_i18n"] = "移動時間",
		["arr_dep_i18n"] = "到着/出発",
		["no_timetable_i18n"] = "時刻表なし",
		["all_i18n"] = "すべて",
		["add_i18n"] = "追加",
		["none_i18n"] = "なし",
		["force_departure_i18n"] = "出発を強制",
		["min_wait_enabled_i18n"] = "最小待機有効",
		["max_wait_enabled_i18n"] = "最大待機有効",
		["margin_time_i18n"] = "マージン時間",
		["tooltip_i18n"] = [[
			各駅に時刻表の制約を追加できます。
			列車が駅に到着すると、その制約を
			保つように努力します。利用可能な制約は:
			- 到着/出発：複数の到着/出発時刻を設定すると、列車は最も近い時刻を選択します
			- 間隔制御：時間間隔を設定すると、車両がその間隔で駅を出発します
		]],
		["modname_name"] = "時刻表",
		["modname_desc"] = "このmodはゲームに時刻表を追加します",
	},
	ko = {
		["arr_i18n"] = "도: ",
		["arrival_i18n"] = "도착",
		["dep_i18n"] = "발: ",
		["departure_i18n"] = "출발",
		["unbunch_time_i18n"] = "간격 제어 시간",
		["unbunch_i18n"] = "간격 제어",
		["auto_unbunch_i18n"] = "자동 간격 제어",
		["timetable_i18n"] = "시간표",
		["timetables_i18n"] = "시간표",
		["line_i18n"] = "노선",
		["lines_i18n"] = "노선",
		["time_min_i18n"] = "분",
		["time_sec_i18n"] = "초",
		["stations_i18n"] = "정거장",
		["frequency_i18n"] = "운행 빈도",
		["journey_time_i18n"] = "소요 시간",
		["arr_dep_i18n"] = "도착/출발",
		["no_timetable_i18n"] = "시간표 없음",
		["all_i18n"] = "전체",
		["add_i18n"] = "추가",
		["none_i18n"] = "없음",
		["force_departure_i18n"] = "강제 출발",
		["min_wait_enabled_i18n"] = "최소 대기 사용",
		["max_wait_enabled_i18n"] = "최대 대기 사용",
		["margin_time_i18n"] = "여유 시간",
		["tooltip_i18n"] = [[
			각 정거장에 시간표 제약을 추가할 수 있습니다.
			열차가 정거장에 도착하면 해당 제약을
			가능한 한 지키려고 합니다. 사용 가능한 제약은 다음과 같습니다:
			- 도착/출발: 여러 도착/출발 시각을 설정하면 열차가 가장 가까운 시각을 선택합니다
			- 간격 제어: 시간 간격을 설정하면 차량이 해당 간격으로 출발합니다
		]],
		["modname_name"] = "시간표",
		["modname_desc"] = "이 모드는 게임에 시간표 기능을 추가합니다",
	},
	tr = {
        ["arr_i18n"] = "Var: ",
        ["arrival_i18n"] = "Varış",
        ["dep_i18n"] = "Kalk: ",
        ["departure_i18n"] = "Kalkış",
        ["unbunch_time_i18n"] = "Düzenleme Süresi",
        ["unbunch_i18n"] = "Düzenleme",
        ["auto_unbunch_i18n"] = "Otomatik Düzenleme",
        ["timetable_i18n"] = "Tarife",
        ["timetables_i18n"] = "Tarifeler",
        ["line_i18n"] = "Hat",
        ["lines_i18n"] = "Hatlar",
        ["time_min_i18n"] = "dk",
        ["time_sec_i18n"] = "sn",
        ["stations_i18n"] = "İstasyonlar",
        ["frequency_i18n"] = "Sıklık",
        ["journey_time_i18n"] = "Yolculuk Süresi",
        ["arr_dep_i18n"] = "Varış/Kalkış",
        ["no_timetable_i18n"] = "Tarife Yok",
        ["all_i18n"] = "Hepsi",
        ["add_i18n"] = "Ekle",
        ["none_i18n"] = "Hiçbiri",
        ["force_departure_i18n"] = "Zorunlu Kalkış",
        ["min_wait_enabled_i18n"] = "Min. bekleme aktif",
        ["max_wait_enabled_i18n"] = "Maks. bekleme aktif",
        ["margin_time_i18n"] = "Pay Süresi",
        ["tooltip_i18n"] = [[
            Her istasyon için tarife kısıtlamaları ekleyebilirsiniz.
            Bir tren istasyona vardığında bu kısıtlamalara uymaya
            çalışacaktır. Mevcut kısıtlamalar:
            - Varış/Kalkış: Birden fazla Var/Kalk saati ayarlayın, tren en yakın varış saatini seçer.
            - Düzenleme: Bir süre belirleyin, araçlar istasyondan sadece bu aralıkla kalkacaktır.
        ]],
        ["modname_name"] = "Zaman Çizelgeleri",
        ["modname_desc"] = "Bu mod oyuna zaman çizelgeleri (tarifeler) ekler.",
    },
	zh_CN = {
		["arr_i18n"] = "到: ",
		["arrival_i18n"] = "到达",
		["dep_i18n"] = "发: ",
		["departure_i18n"] = "出发",
		["unbunch_time_i18n"] = "发车间隔",
		["unbunch_i18n"] = "间隔控制",
		["auto_unbunch_i18n"] = "自动间隔控制",
		["timetable_i18n"] = "时刻表",
		["timetables_i18n"] = "时刻表",
		["line_i18n"] = "线路",
		["lines_i18n"] = "线路",
		["time_min_i18n"] = "分",
		["time_sec_i18n"] = "秒",
		["stations_i18n"] = "车站",
		["frequency_i18n"] = "频率",
		["journey_time_i18n"] = "旅时",
		["arr_dep_i18n"] = "到发时刻",
		["no_timetable_i18n"] = "无时刻表",
		["all_i18n"] = "全部",
		["add_i18n"] = "添加",
		["none_i18n"] = "无",
		["force_departure_i18n"] = "强制出发",
		["min_wait_enabled_i18n"] = "最短等待已启用",
		["max_wait_enabled_i18n"] = "最长等待已启用",
		["margin_time_i18n"] = "余量时间",
		["tooltip_i18n"] = [[
			你可以对每个站点添加时刻表约束。
			列车到站后会尽量遵循约束条件。可用的约束模式包括：
			- 到发时刻：设定多组到发时刻，列车会选择最近的时刻
			- 间隔控制：设定时间长度，载具以给定间隔发车
		]],
		["modname_name"] = "时刻表",
		["modname_desc"] = "本模组为游戏添加时刻表系统",
	},
	zh_TW = {
		["arr_i18n"] = "到: ",
		["arrival_i18n"] = "到達",
		["dep_i18n"] = "發: ",
		["departure_i18n"] = "出發",
		["unbunch_time_i18n"] = "發車間隔",
		["unbunch_i18n"] = "間隔控制",
		["auto_unbunch_i18n"] = "自動間隔控制",
		["timetable_i18n"] = "時刻表",
		["timetables_i18n"] = "時刻表",
		["line_i18n"] = "路線",
		["lines_i18n"] = "路線",
		["time_min_i18n"] = "分",
		["time_sec_i18n"] = "秒",
		["stations_i18n"] = "車站",
		["frequency_i18n"] = "頻率",
		["journey_time_i18n"] = "旅時",
		["arr_dep_i18n"] = "到發時刻",
		["no_timetable_i18n"] = "無時刻表",
		["all_i18n"] = "全部",
		["add_i18n"] = "添加",
		["none_i18n"] = "無",
		["force_departure_i18n"] = "強制出發",
		["min_wait_enabled_i18n"] = "最短等待已啟用",
		["max_wait_enabled_i18n"] = "最長等待已啟用",
		["margin_time_i18n"] = "餘量時間",
		["tooltip_i18n"] = [[
			你可以對各個站點添加時刻表約束。
			列車到站後會儘量遵循約束條件。可用的約束模式包括：
			- 到發時刻：設定多組到發時刻，列車會選擇最近的時刻
			- 間隔控制：設定時間長度，載具以給定間隔發車
		]],
		["modname_name"] = "時刻表",
		["modname_desc"] = "本模組爲遊戲添加時刻表系統",
	}
}
end