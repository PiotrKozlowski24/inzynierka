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

cisnienie = T.x402LBA10FP950_av_Ci_nienieParyZaKot_em;

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

xlabel("Czas")

ax = findobj(gcf,'Type','axes');
linkaxes(ax,'x')

%%
window = 10;
t_start = datetime(2026,2,3,2,0,0);
t_end   = datetime(2026,2,3,5,0,0);

idx = (time >= t_start) & (time <= t_end);

time_f = time(idx);
valve_f = pozycja_zaworu_wtrysku_1_strL(idx);
flow_f = smoothdata(przeplyw_do_schl_1(idx), 'gaussian', window);
temp_wtr_f = smoothdata(pomiar_temp_za_wtryskiem_1_strL(idx), 'gaussian', window);
temp_przegr_f = smoothdata(pomiar_temp_za_przeg_1_strL(idx), 'gaussian', window);

figure;

subplot(4,1,1)
plot(time_f, valve_f, 'Color', [0 0.4470 0.7410])
grid on
title("Pozycja zaworu")

subplot(4,1,2)
plot(time_f, flow_f, 'Color', [0.8500 0.3250 0.0980])
grid on
title("Przepływ (filtered)")

subplot(4,1,3)
plot(time_f, temp_wtr_f, 'Color', [0.9290 0.6940 0.1250])
grid on
title("Temp za wtryskiem")

subplot(4,1,4)
plot(time_f, temp_przegr_f, 'Color', [0.4940 0.1840 0.5560])
grid on
title("Temp za przegrzewaczem")

xlabel("Time")

%% Cisnienie - zawór - przeplyw
window = 500;
t_start = datetime(2026,2,7,20,0,0);
t_end   = datetime(2026,2,8,10,0,0);

idx = (time > t_start) & (time < t_end);

time_f = time(idx);

cisnienie_f  = medfilt1(cisnienie(idx),  window);
przeplyw_f   = medfilt1(przeplyw_do_schl_1(idx), window);

figure;

subplot(3,1,1)
plot(time_f, cisnienie_f, 'Color', [0 0.4470 0.7410])
grid on
title("Ciśnienie")

subplot(3,1,2)
plot(time_f, pozycja_zaworu_wtrysku_1_strL(idx), 'Color', [0.8500 0.3250 0.0980])
grid on
title("Pozycja zaworu")

subplot(3,1,3)
plot(time_f, przeplyw_f, 'Color', [0.9290 0.6940 0.1250])
grid on
title("Przepływ wtrysku [t/h]")

xlabel("Time")

ax = findobj(gcf,'Type','axes');
linkaxes(ax,'x')



%% Cisnienie
figure;
plot(time, cisnienie, 'LineWidth', 1.5)
hold on;
plot(time, pozycja_zaworu_wtrysku_1_strL, 'LineWidth', 1.5)
grid on;
legend("Cisnienie", "Pozycja zaworu", 'Location', 'best');
xlabel("Czas"); ylabel("Wartość");
title("Ciśnienie i pozycja zaworu");
%%
p_ref = 12.9;
p_tol = 0.05;
idx = abs(cisnienie - p_ref) <= p_tol;
u = pozycja_zaworu_wtrysku_1_strL(idx);
q = przeplyw_do_schl_1(idx);
valid = ~(isnan(u) | isnan(q));
u = u(valid);
q = q(valid);
%%
figure;
scatter(u, q, 20, 'filled', 'MarkerFaceAlpha', 0.4)
grid on;
xlabel('Pozycja zaworu [%]');
ylabel('Przepływ [t/h]');
title(sprintf('Charakterystyka zaworu  p = %.1f ± %.2f bar', p_ref, p_tol));
%%
p = polyfit(u, q, 1);
a = p(1); b = p(2);
fprintf('Q = %.4f * u + %.4f\n', a, b);

%%
u_fit = linspace(min(u), max(u), 200);
q_fit = polyval(p, u_fit);
q_est = polyval(p, u);
R2 = 1 - sum((q - q_est).^2) / sum((q - mean(q)).^2);
fprintf('R² = %.4f\n', R2);

figure;
scatter(u, q, 20, 'filled', 'MarkerFaceAlpha', 0.4, 'DisplayName', 'Dane')
hold on;
plot(u_fit, q_fit, 'LineWidth', 2, 'DisplayName', sprintf('F(u) = %.4f·u + %.4f', a, b))
grid on;
legend('Location', 'best');
xlabel('Pozycja zaworu [%]'); ylabel('Przepływ [t/h]');
title(sprintf('Charakterystyka zaworu  p = %.1f ± %.2f bar', p_ref, p_tol));

%%
window = 200;

% --- filtr ciśnienia ---
idx2 = abs(cisnienie - p_ref) <= p_tol;

time_cmp = time(idx2);
u_cmp    = pozycja_zaworu_wtrysku_1_strL(idx2);
q_raw    = przeplyw_do_schl_1(idx2);

% --- filtr czasowy ---
mask = time_cmp >= datetime(2026,2,6) & time_cmp <= datetime(2026,2,11);

time_cmp = time_cmp(mask);
u_cmp    = u_cmp(mask);
q_raw    = q_raw(mask);

% --- filtracja sygnału (po pełnym przycięciu danych) ---
q_real = medfilt1(q_raw, window);

% --- model liniowy ---
q_model = a * u_cmp + b;

% --- wykres ---
figure;

subplot(2,1,1);
plot(time_cmp, q_real, 'LineWidth', 1.5, 'DisplayName', 'Przepływ rzeczywisty');
hold on;
plot(time_cmp, q_model, '--', 'LineWidth', 1.5, 'DisplayName', 'Model liniowy');

grid on;
legend('Location', 'best');
ylabel('Przepływ [t/h]');
title('Porównanie modelu zaworu z danymi (6–11 lutego)');

subplot(2,1,2);
plot(time_cmp, u_cmp, 'LineWidth', 1.5, 'Color', [0.85 0.33 0.10]);
grid on;
ylabel('Pozycja zaworu [%]');
xlabel('Czas');

linkaxes(findall(gcf,'Type','axes'), 'x');

%% 

% Przygotuj dane (wszystkie punkty naraz, nie tylko dwa ciśnienia)
u_all = pozycja_zaworu_wtrysku_1_strL;
p_all = cisnienie;
q_all = przeplyw_do_schl_1;

%% Przygotuj dane 2D
valid = ~isnan(pozycja_zaworu_wtrysku_1_strL) & ...
        ~isnan(cisnienie) & ...
        ~isnan(przeplyw_do_schl_1);

u_fit = pozycja_zaworu_wtrysku_1_strL(valid);
p_fit = cisnienie(valid);
q_fit = przeplyw_do_schl_1(valid);

%% Opcja A - GUI (wybierz typ modelu interaktywnie)
cftool(u_fit, p_fit, q_fit)

%% Opcja B - z kodu, porównaj kilka modeli
models = {'poly11','poly12','poly21','poly22','poly23','poly33'};

for i = 1:length(models)
    [sf, gof] = fit([u_fit, p_fit], q_fit, models{i});
    fprintf('%-8s  R²=%.4f  RMSE=%.6f\n', models{i}, gof.rsquare, gof.rmse);
end

%% WYkres wtrysku i przegrzewacza (bloki inercyjne)
window = 10;
t_start = datetime(2026,2,15,5,0,0);
t_end   = datetime(2026,2,15,7,0,0);

idx = (time >= t_start) & (time <= t_end);

time_f = time(idx);

flow_f = smoothdata(przeplyw_do_schl_1(idx), 'gaussian', window);
temp_wtr_f = smoothdata(pomiar_temp_za_wtryskiem_1_strL(idx), 'gaussian', window);
temp_przegr_f = smoothdata(pomiar_temp_za_przeg_1_strL(idx), 'gaussian', window);

figure;



subplot(3,1,1)
plot(time_f, flow_f, 'Color', [0.8500 0.3250 0.0980])
grid on
title("Przepływ")

subplot(3,1,2)
plot(time_f, temp_wtr_f, 'Color', [0.9290 0.6940 0.1250])
grid on
title("Temp za wtryskiem")

subplot(3,1,3)
plot(time_f, temp_przegr_f, 'Color', [0.4940 0.1840 0.5560])
grid on
title("Temp za przegrzewaczem")

xlabel("Time")

%% Dopasowanie modelu do odpowiedzi wtrysku
Ts = 5;

y = temp_wtr_f;
u = flow_f;

y0 = mean(y(1:500));
u0 = mean(u(1:500));

y0_wtr = y0;
u0_wtr = u0;

data = iddata(y - y0, u - u0, Ts);
sys_wtr = tfest(data, 1);

tf(sys_wtr)
K_wtr = dcgain(sys_wtr)
p = pole(sys_wtr)
T_wtr = (-1/p)/Ts

compare(data,sys_wtr)

%% Porównanie modelu wtryskiwacza z oryginałem
y_wtrysk_model = lsim(sys_wtr, u - u0_wtr, seconds(time_f - time_f(1))) + y0_wtr;

figure;
subplot(2,1,1)
plot(time_f, flow_f, 'Color', [0.8500 0.3250 0.0980])
grid on
title("Przepływ")

subplot(2,1,2)
plot(time_f, temp_wtr_f)
hold on
plot(time_f, y_wtrysk_model, '--r')
grid on
title("Temp za wtryskiem")
legend('Pomiar', 'Model')
xlabel("Time")

%% Dopasowanie modelu do odpowiedzi przegrzewacza
Ts = 5;

y = temp_przegr_f;
u = temp_wtr_f;

y0 = mean(y(1:500));
u0 = mean(u(1:500));

y0_przeg = y0;
u0_przeg = u0;

data = iddata(y - y0, u - u0, Ts);
sys_przeg = tfest(data, 1);

tf(sys_przeg)
K_przeg = dcgain(sys_przeg)
p = pole(sys_przeg)
T_przeg = (-1/p)/Ts

compare(data,sys_przeg)

%% Porównanie modelu przegrzewacza z oryginałem
y_przeg_model = lsim(sys_przeg, u - u0_przeg, seconds(time_f - time_f(1))) + y0_przeg;

figure;
subplot(2,1,1)
plot(time_f, temp_wtr_f, 'Color', [0.8500 0.3250 0.0980])
grid on
title("Temp przed przegrzewaczem")

subplot(2,1,2)
plot(time_f, temp_przegr_f)
hold on
plot(time_f, y_przeg_model, '--r')
grid on
title("Temp za przegrzewaczem")
legend('Pomiar', 'Model')
xlabel("Time")

%% Wykresy modeli dla całego czasu

flow_all = smoothdata(przeplyw_do_schl_1, 'gaussian', window);
temp_wtr_all = smoothdata(pomiar_temp_za_wtryskiem_1_strL, 'gaussian', window);
temp_przegr_all = smoothdata(pomiar_temp_za_przeg_1_strL, 'gaussian', window);

t_all = (0:length(time)-1)' * Ts;

y_wtr_all = lsim(sys_wtr, flow_all - u0_wtr, t_all) + y0_wtr;

y_przeg_all = lsim(sys_przeg, temp_wtr_all - u0_przeg, t_all) + y0_przeg;

figure;

subplot(2,1,1)
plot(time, temp_wtr_all)
hold on
plot(time, y_wtr_all, '--r', 'LineWidth', 1.2)
grid on
title("Temp za wtryskiem - cały czas")
legend('Pomiar', 'Model')
xlabel("Time")

subplot(2,1,2)
plot(time, temp_przegr_all)
hold on
plot(time, y_przeg_all, '--r', 'LineWidth', 1.2)
grid on
title("Temp za przegrzewaczem - cały czas")
legend('Pomiar', 'Model')
xlabel("Time")

%% Wykresy modeli dla okresów modelowania zaworu

window = 200;

p_ref = 12.9;
p_tol = 0.05;

idx_model = abs(cisnienie - p_ref) <= p_tol;

time_model = time(idx_model);
valve_model = pozycja_zaworu_wtrysku_1_strL(idx_model);
flow_model = przeplyw_do_schl_1(idx_model);
temp_wtr_model = pomiar_temp_za_wtryskiem_1_strL(idx_model);
temp_przegr_model = pomiar_temp_za_przeg_1_strL(idx_model);

mask = time_model >= datetime(2026,2,6) & ...
       time_model <= datetime(2026,2,11);

time_model = time_model(mask);
valve_model = valve_model(mask);
flow_model = medfilt1(flow_model(mask), window);
temp_wtr_model = smoothdata(temp_wtr_model(mask), 'gaussian', 10);
temp_przegr_model = smoothdata(temp_przegr_model(mask), 'gaussian', 10);

t_model = (0:length(time_model)-1)' * Ts;

y_wtr_model = lsim(sys_wtr, flow_model - u0_wtr, t_model) + y0_wtr;
y_przeg_model = lsim(sys_przeg, temp_wtr_model - u0_przeg, t_model) + y0_przeg;

q_model = a * valve_model + b;

figure;

subplot(4,1,1)
plot(time_model, valve_model)
grid on
title("Pozycja zaworu")
ylabel("[%]")

subplot(4,1,2)
plot(time_model, flow_model)
hold on
plot(time_model, q_model, '--r', 'LineWidth', 1.2)
grid on
title("Przepływ")
legend('Pomiar', 'Model zaworu')
ylabel("[t/h]")

subplot(4,1,3)
plot(time_model, temp_wtr_model)
hold on
plot(time_model, y_wtr_model, '--r', 'LineWidth', 1.2)
grid on
title("Temp za wtryskiem")
legend('Pomiar', 'Model')
ylabel("[°C]")

subplot(4,1,4)
plot(time_model, temp_przegr_model)
hold on
plot(time_model, y_przeg_model, '--r', 'LineWidth', 1.2)
grid on
title("Temp za przegrzewaczem")
legend('Pomiar', 'Model')
ylabel("[°C]")
xlabel("Time")

linkaxes(findall(gcf,'Type','axes'), 'x')

%% Wypisanie parametrów inercji

disp('Wzmocnienie wtryskiwacza K1: ')
disp(K_wtr)

disp('Stała czasowa wtryskiwacza T1: ')
disp(T_wtr)

disp('Wzmocnienie przegrzewazca K2: ')
disp(K_przeg)

disp('Stała czasowa przegrzewacza T2: ')
disp(T_przeg)

T_przeg_T_wtr = T_przeg/T_wtr;

disp('Iloraz T2/T1:')
disp(T_przeg_T_wtr)

save('parametry_inercji.mat', 'K_wtr', 'T_wtr', 'K_przeg', 'T_przeg', 'T_przeg_T_wtr');