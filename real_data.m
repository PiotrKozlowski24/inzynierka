%% READ INDUSTRIAL CSV FILE

clear
clc

%% FILE
file = 'bfb_01.csv';

%% READ HEADER ROWS
fid = fopen(file);

header1 = fgetl(fid);
header2 = fgetl(fid);

fclose(fid);

%% CREATE VARIABLE NAMES
names1 = strsplit(header1, ';');
names2 = strsplit(header2, ';');

newNames = strcat(names1, "_", names2);

newNames = matlab.lang.makeValidName(newNames);
newNames = newNames(1:end-1);

%% IMPORT OPTIONS
opts = detectImportOptions(file, ...
    'Delimiter',';');

% Data starts from line 3
opts.DataLines = [3 Inf];

%% READ TABLE
T = readtable(file, opts);
%% APPLY VARIABLE NAMES
T.Properties.VariableNames = newNames;

%% CONVERT DECIMAL COMMA TO DOT
for k = 2:width(T)

    col = T{:,k};

    if iscell(col) || isstring(col)

        col = strrep(string(col), ",", ".");
        T.(T.Properties.VariableNames{k}) = str2double(col);

    end

end

%% SAVE TABLE
save('bfb_01_processed.mat', 'T');

%% LOAD TABLE
load('bfb_01_processed.mat');
%% TIME VECTOR
time = datetime(T.Time_, ...
    'InputFormat','dd.MM.yyyy HH:mm');

%% EXAMPLE SIGNALS
temp_przed_schl_1_L = T.x402HAH11CT201_av_Temp1paryPrzedSch__1st_L;
temp_za_schl_1_L = T.x402HAH13FT950_av_T_paryZaSch_1Sel;
temp_za_przeg_2_L = T.x402HAH21FT950_av_T_paryZaPrzegrz2Sel;
temp_za_schl_2_L = T.x402HAH23FT950_av_T_paryZaSch_2Sel;
temp_za_przeg_3_L = T.x402HAH31FT950_av_T_paryZaPrzegrz3Sel;
temp_przed_schl_1_P = T.x402HAH12CT201_av_Temp1paryPrzedSch__1st_P;
temp_za_schl_1_P = T.x402HAH14FT950_av_T_paryZaSch_1Sel;
temp_za_przeg_2_P = T.x402HAH22FT950_av_T_paryZaPrzegrz2Sel;
temp_za_schl_2_P = T.x402HAH24FT950_av_T_paryZaSch_2Sel;
temp_za_przeg_3_P = T.x402HAH32FT950_av_T_paryZaPrzegrz3Sel;

pomiar_temp_za_przeg_1_strL = T.x402HAH21DT950_me_PomiarTParyZaPrzeg1stStrL;
wart_zad_temp_za_przeg_1_strL = T.x402HAH21DT950_spa_WarZadTParyZaPrzeg1stStrL;

pomiar_temp_za_wtryskiem_1_strL = T.x402HAH13DT950_me_PomiarTParyZa1stWtryskL;
wart_zad_temp_za_wtryskiem_1_strL = T.x402HAH13DT950_spa_WarZadTParyZa1stWtryskL;
przeplyw_do_schl_1 = T.x402LAE11FF901_av_Przep__wod_zrasz_do_sch__1;

pozycja_zaworu_wtrysku_1_strL = T.x402LAE11AA401_pos_POZYCJAZaw_regul_wtrys_1st_L_2C;

%%
figure;
plot(time, pomiar_temp_za_wtryskiem_1_strL)
hold on;
plot(time, wart_zad_temp_za_wtryskiem_1_strL, "LineStyle", "--")
grid on;

legend( ...
    "Pomiar T za wtryskiem", ...
    "Wartość zadana T za wtryskiem" ...
);

title("Temperatura za wtryskiem")
xlabel("Time")
ylabel("Temperature")

%% DIFFERENCE
temp_diff = pomiar_temp_za_wtryskiem_1_strL - wart_zad_temp_za_wtryskiem_1_strL;


figure;
plot(time, temp_diff)
grid on;

legend("Różnica (pomiar - zadana)");

title("Błąd temperatury")
xlabel("Time")
ylabel("ΔT")

%% FLOW + VALVE POSITION

figure;
plot(time, przeplyw_do_schl_1)
hold on
plot(time, pozycja_zaworu_wtrysku_1_strL)

grid on;

legend( ...
    "Przepływ wody do schładzania 1", ...
    "Pozycja zaworu wtrysku 1" ...
);

title("Układ wtrysku i chłodzenia")
xlabel("Time")

%% Dynamika całego układu
figure;

subplot(4,1,1)
plot(time, pozycja_zaworu_wtrysku_1_strL, 'Color', [0 0.4470 0.7410])
grid on
title("Pozycja zaworu")

subplot(4,1,2)
plot(time, przeplyw_do_schl_1, 'Color', [0.8500 0.3250 0.0980])
grid on
title("Przepływ")

subplot(4,1,3)
plot(time, pomiar_temp_za_wtryskiem_1_strL, 'Color', [0.9290 0.6940 0.1250])
grid on
title("Temp za wtryskiem")

subplot(4,1,4)
plot(time, pomiar_temp_za_przeg_1_strL, 'Color', [0.4940 0.1840 0.5560])
grid on
title("Temp za przegrzewaczem")

xlabel("Time")

ax = findobj(gcf,'Type','axes');
linkaxes(ax,'x')