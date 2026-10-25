
clear
clc
close all
s = tf('s');

%% Parametry
T1_vals = linspace(1,20, 128);
T2_vals = linspace(20,200,128);
L2_vals = 0;

nL = numel(L2_vals);
nT2 = numel(T2_vals);
nT1 = numel(T1_vals);

t_sim = 0:0.1:3000;
opts = pidtuneOptions('PhaseMargin',60);
ratioMax = 3;   % stała skala ilorazów: [1/ratioMax, ratioMax], np. [0.25 4]
                % użyj tej samej wartości co cfg.ratioMax w skrypcie z mapami T2/T1 x L2

%% Prealokacja wskaźników jakości
riseTime     = zeros(nL,nT2,nT1);
overshoot    = zeros(nL,nT2,nT1);
settlingTime = zeros(nL,nT2,nT1);
ITAE         = zeros(nL,nT2,nT1);

riseTime_c     = zeros(nL,nT2,nT1);
overshoot_c    = zeros(nL,nT2,nT1);
settlingTime_c = zeros(nL,nT2,nT1);
ITAE_c         = zeros(nL,nT2,nT1);

%% Prealokacja wskaźników sygnałów sterujących
maxU = zeros(nL,nT2,nT1);
rmsU = zeros(nL,nT2,nT1);
IAEU = zeros(nL,nT2,nT1);

maxU_c_P = zeros(nL,nT2,nT1);
rmsU_c_P = zeros(nL,nT2,nT1);
IAEU_c_P = zeros(nL,nT2,nT1);

maxU_c_PI = zeros(nL,nT2,nT1);
rmsU_c_PI = zeros(nL,nT2,nT1);
IAEU_c_PI = zeros(nL,nT2,nT1);



%% Symulacja
fprintf('Rozpoczynam symulacje...\n');
licznik = 0;
N = nL*nT2*nT1;
for k = 1:nL
    L2 = L2_vals(k);
    fprintf('L2 = %.1f (%d/%d)\n',L2,k,nL);

    for i = 1:nT2
        for j = 1:nT1

            T1 = T1_vals(j);
            T2 = T2_vals(i);

            G_s = 1/(T1*s+1);
            G_p = tf(1,[T2 1],'InputDelay',L2);
            G_total = G_s*G_p;

            %% UKŁAD JEDNOPĘTLOWY PI
            C = pidtune(G_total,'PI',opts);
            T_cl = feedback(C*G_total,1);

            info = stepinfo(T_cl);
            riseTime(k,i,j) = info.RiseTime;
            overshoot(k,i,j) = info.Overshoot;
            settlingTime(k,i,j) = info.SettlingTime;

            [y,t] = step(T_cl,t_sim);
            y = squeeze(y);
            t = squeeze(t);

            ITAE(k,i,j) = trapz(t,t.*abs(1-y));

            % Sygnał sterujący regulatora PI
            U_single = feedback(C,G_total);
            u_single = squeeze(step(U_single,t_sim));

            maxU(k,i,j) = max(abs(u_single));
            rmsU(k,i,j) = sqrt(mean(u_single.^2));
            IAEU(k,i,j) = trapz(t_sim,abs(u_single));

            %% UKŁAD KASKADOWY P + PI

            % P - regulator pętli wewnętrznej
            C1 = pidtune(G_s,'P',opts);
            T_inner = feedback(C1*G_s,1);

            % PI - regulator pętli zewnętrznej
            G_outer = T_inner*G_p;
            C2 = pidtune(G_outer,'PI',opts);

            T_cascade = feedback(C2*G_outer,1);

            info_c = stepinfo(T_cascade);
            riseTime_c(k,i,j) = info_c.RiseTime;
            overshoot_c(k,i,j) = info_c.Overshoot;
            settlingTime_c(k,i,j) = info_c.SettlingTime;

            [yc,tc] = step(T_cascade,t_sim);
            yc = squeeze(yc);
            tc = squeeze(tc);

            ITAE_c(k,i,j) = trapz(tc,tc.*abs(1-yc));

            %% SYGNAŁY STERUJĄCE W KASKADZIE

            % Wyjście regulatora PI:
            % sygnał zadany dla pętli wewnętrznej
            U_c_PI = feedback(C2,T_inner*G_p);
            u_c_PI = squeeze(step(U_c_PI,t_sim));

            % Wyjście regulatora P:
            % sterowanie obiektem wewnętrznym
            U_c_P = feedback(C1,G_s)*U_c_PI;
            u_c_P = squeeze(step(U_c_P,t_sim));

            % Wskaźniki regulatora P
            maxU_c_P(k,i,j) = max(abs(u_c_P));
            rmsU_c_P(k,i,j) = sqrt(mean(u_c_P.^2));
            IAEU_c_P(k,i,j) = trapz(t_sim,abs(u_c_P));

            % Wskaźniki regulatora PI
            maxU_c_PI(k,i,j) = max(abs(u_c_PI));
            rmsU_c_PI(k,i,j) = sqrt(mean(u_c_PI.^2));
            IAEU_c_PI(k,i,j) = trapz(t_sim,abs(u_c_PI));

            licznik = licznik + 1;
            fprintf('Postęp symulacji: %.1f%% (%d/%d)\n', ...
                100*licznik/N, licznik, N);

        end
    end
end

fprintf('Symulacje zakończone.\n');

%% ZAPIS WYNIKÓW
resultsFile = 'simulation_results_bez_zaklocen.mat';

save(resultsFile, ...
    'riseTime','overshoot','settlingTime','ITAE', ...
    'riseTime_c','overshoot_c','settlingTime_c','ITAE_c', ...
    'maxU','rmsU','IAEU', ...
    'maxU_c_P','rmsU_c_P','IAEU_c_P', ...
    'maxU_c_PI','rmsU_c_PI','IAEU_c_PI', ...
    'T1_vals','T2_vals','L2_vals');

fprintf('Wyniki zapisano do %s\n',resultsFile);

%%
load("simulation_results_bez_zaklocen.mat")

%% MAPY CIEPLNE: WSKAŹNIKI JAKOŚCI REGULACJI

metrics = {'Czas narastania', ...
           'Przeregulowanie (%)', ...
           'Czas regulacji', ...
           'ITAE'};

data_single = {riseTime,overshoot,settlingTime,ITAE};
data_cascade = {riseTime_c,overshoot_c,settlingTime_c,ITAE_c};

for k = 1:nL
    L2 = L2_vals(k);

    for m = 1:numel(metrics)
        D  = squeeze(data_single{m}(k,:,:));
        Dc = squeeze(data_cascade{m}(k,:,:));
        Dd = D./(Dc+eps);

        figure('Name',sprintf('L2=%.2f | %s',L2,metrics{m}), ...
            'NumberTitle','off');

        plotRatioMap(T1_vals,T2_vals,Dd,ratioMax);

        xlabel('T_1');
        ylabel('T_2');
        title(sprintf('%s: jednopętlowy / kaskadowy, L_2=%.1f', ...
            metrics{m},L2));
    end
end
%% MAPY CIEPLNE: SYGNAŁY STERUJĄCE

control_names = { ...
    'Maks. |u|: PI jednopętlowy / P kaskadowy', ...
    'RMS(u): PI jednopętlowy / P kaskadowy', ...
    'IAE(u): PI jednopętlowy / P kaskadowy', ...
    'Maks. |u|: PI jednopętlowy / PI kaskadowy', ...
    'RMS(u): PI jednopętlowy / PI kaskadowy', ...
    'IAE(u): PI jednopętlowy / PI kaskadowy'};

control_single = {maxU,rmsU,IAEU,maxU,rmsU,IAEU};

control_cascade = {maxU_c_P,rmsU_c_P,IAEU_c_P, ...
                   maxU_c_PI,rmsU_c_PI,IAEU_c_PI};

for k = 1:nL
    for m = 1:numel(control_names)
        D = squeeze(control_single{m}(k,:,:));
        Dc = squeeze(control_cascade{m}(k,:,:));

        Dd = D./(Dc+eps);

        figure('Name',control_names{m},'NumberTitle','off');

        imagesc(T1_vals,T2_vals,Dd);
        set(gca,'YDir','normal');
        colormap(gca,redblue_centered(Dd,1));
        colorbar;

        xlabel('T_1');
        ylabel('T_2');
        title(control_names{m});
    end
end

%% ANALIZA WZGLĘDEM STOSUNKU T2/T1

ratio_min = 1;
ratio_max = 200;
nBins_plot = 1000;
nBins_trend = 30;

ratio_edges_plot = logspace(log10(ratio_min), ...
                            log10(ratio_max),nBins_plot+1);
ratio_centers_plot = ...
    (ratio_edges_plot(1:end-1)+ratio_edges_plot(2:end))/2;

ratio_edges_trend = logspace(log10(ratio_min), ...
                             log10(ratio_max),nBins_trend+1);
ratio_centers_trend = ...
    (ratio_edges_trend(1:end-1)+ratio_edges_trend(2:end))/2;

for m = 1:numel(metrics)

    figure('Name',['Stosunek T2/T1 - ' metrics{m}], ...
        'NumberTitle','off');
    hold on;
    grid on;

    all_ratios = [];
    all_values = [];

    for k = 1:nL
        ratios_all = [];
        y_vals = [];

        for i = 1:nT2
            for j = 1:nT1
                ratio_param = T2_vals(i)/T1_vals(j);

                if ratio_param >= ratio_min && ratio_param <= ratio_max
                    val_single = data_single{m}(k,i,j);
                    val_cascade = data_cascade{m}(k,i,j);

                    ratio_val = val_single/(val_cascade+eps);

                    if isfinite(ratio_val)
                        ratios_all(end+1) = ratio_param;
                        y_vals(end+1) = ratio_val;
                    end
                end
            end
        end

        all_ratios = [all_ratios ratios_all];
        all_values = [all_values y_vals];

        mean_ratio = nan(1,nBins_plot);

        for b = 1:nBins_plot
            idx = ratios_all >= ratio_edges_plot(b) & ...
                  ratios_all < ratio_edges_plot(b+1);

            if any(idx)
                mean_ratio(b) = mean(y_vals(idx));
            end
        end

        idx = ~isnan(mean_ratio);

        plot(ratio_centers_plot(idx),mean_ratio(idx), ...
            'LineWidth',1.5, ...
            'DisplayName',sprintf('L_2 = %.1f',L2_vals(k)));
    end

    mean_trend = nan(1,nBins_trend);

    for b = 1:nBins_trend
        idx = all_ratios >= ratio_edges_trend(b) & ...
              all_ratios < ratio_edges_trend(b+1);

        if any(idx)
            mean_trend(b) = mean(all_values(idx));
        end
    end

    idx = ~isnan(mean_trend);

    plot(ratio_centers_trend(idx),mean_trend(idx), ...
        'r','LineWidth',3,'DisplayName','Średni trend');

    yline(1,'--k','HandleVisibility','off');
    xlim([1 200]);
    set(gca,'XScale','log');
    set(gca,'XTick',[1 2 5 10 20 50 100 200]);

    xlabel('T_2/T_1');
    ylabel('Stosunek jednopętlowy/kaskadowy');
    title(['Stosunek wskaźników: ' metrics{m}]);
    legend('show','Location','best');
end

%% Stalosc ilorazu ITAE dla stalego T2/T1

figure;
hold on;
grid on;

ratios_check = [5 9 15 20 50 80 150];
colors = lines(numel(ratios_check));
tol = 0.015;

for r = 1:numel(ratios_check)

    ratio_target = ratios_check(r);

    x = [];
    q_values = [];

    for i = 1:nT2
        for j = 1:nT1

            T1 = T1_vals(j);
            T2 = T2_vals(i);
            ratio = T2/T1;

            if abs(ratio-ratio_target)/ratio_target < tol

                q = ITAE(1,i,j)/(ITAE_c(1,i,j)+eps);

                x(end+1) = T1;
                q_values(end+1) = q;
            end
        end
    end

    plot(x, q_values, '.', ...
        'Color', colors(r,:), ...
        'MarkerSize', 12, ...
        'DisplayName', sprintf('T_2/T_1 = %g',ratio_target));
end

xlabel('T_1');
ylabel('ITAE jednopętlowy / ITAE kaskadowy');
title('Iloraz ITAE dla stałych stosunków T_2/T_1');
legend('Location','best');
%% PRZYKŁADOWE ODPOWIEDZI I SYGNAŁY STERUJĄCE

T1_ex = 2;
ratios_ex = [2 5 10 20 50 100];
L2_ex = 0;
nEx = numel(ratios_ex);

fig1 = figure('Name','Odpowiedź skokowa','NumberTitle','off');
tl1 = tiledlayout(fig1,ceil(nEx/2),2,'TileSpacing','compact');

fig2 = figure('Name','Sygnały sterujące','NumberTitle','off');
tl2 = tiledlayout(fig2,ceil(nEx/2),2,'TileSpacing','compact');

fig3 = figure('Name','Sygnały sterujące - powiększenie', ...
    'NumberTitle','off');
tl3 = tiledlayout(fig3,ceil(nEx/2),2,'TileSpacing','compact');


%% PRZYKŁADOWE ODPOWIEDZI I SYGNAŁY STERUJĄCE

T1_ex = 2;
ratios_ex = [5 20 100];  % Tylko 3 przykłady
L2_ex = 0;
nEx = numel(ratios_ex);

lineWidth = 2;  % Grubość linii

fig1 = figure('Name','Odpowiedzi skokowe','NumberTitle','off');
tl1 = tiledlayout(fig1, nEx, 1, 'TileSpacing','compact');

fig2 = figure('Name','Sygnały sterujące','NumberTitle','off');
tl2 = tiledlayout(fig2, nEx, 1, 'TileSpacing','compact');

fig3 = figure('Name','Sygnały sterujące - powiększenie', ...
    'NumberTitle','off');
tl3 = tiledlayout(fig3, nEx, 1, 'TileSpacing','compact');

for n = 1:nEx

    T1 = T1_ex;
    T2 = ratios_ex(n)*T1;

    G_s = 1/(T1*s+1);
    G_p = tf(1,[T2 1],'InputDelay',L2_ex);
    G_total = G_s*G_p;

    %% Układ jednopętlowy PI
    C = pidtune(G_total,'PI',opts);
    T_cl = feedback(C*G_total,1);

    %% Układ kaskadowy P + PI
    C1 = pidtune(G_s,'P',opts);
    T_inner = feedback(C1*G_s,1);

    G_outer = T_inner*G_p;
    C2 = pidtune(G_outer,'PI',opts);

    T_casc = feedback(C2*G_outer,1);

    %% Odpowiedzi skokowe
    y_s = squeeze(step(T_cl,t_sim));
    y_c = squeeze(step(T_casc,t_sim));

    nexttile(tl1);
    plot(t_sim,y_s,'b', ...
         t_sim,y_c,'r','LineWidth',lineWidth);
    grid on;
    yline(1,'--k','HandleVisibility','off');

    title(sprintf('T_2/T_1=%g (T_1=%g, T_2=%g)', ...
        ratios_ex(n),T1,T2));

    xlim([0 min(t_sim(end),10*T2)]);
    xlabel('t');
    ylabel('y');

    if n==1
        legend('Jednopętlowy PI','Kaskadowy P+PI', ...
            'Location','best');
    end

    %% Sygnały sterujące
    U_single = feedback(C,G_total);
    u_s = squeeze(step(U_single,t_sim));

    U_c_PI = feedback(C2,T_inner*G_p);
    u_PI = squeeze(step(U_c_PI,t_sim));

    U_c_P = feedback(C1,G_s)*U_c_PI;
    u_P = squeeze(step(U_c_P,t_sim));

    %% Pełne przebiegi sygnałów sterujących
    nexttile(tl2);
    plot(t_sim,u_s,'b', ...
         t_sim,u_P,'r', ...
         t_sim,u_PI,'k','LineWidth',lineWidth);
    grid on;

    title(sprintf('T_2/T_1=%g | max|u|: %.2f / %.2f / %.2f', ...
        ratios_ex(n),max(abs(u_s)),max(abs(u_P)),max(abs(u_PI))));

    xlim([0 min(t_sim(end),10*T2)]);
    xlabel('t');
    ylabel('u');

    if n==1
        legend('PI jednopętlowy','P kaskadowy', ...
            'PI kaskadowy','Location','best');
    end

    %% Powiększenie sygnałów sterujących
    nexttile(tl3);
    plot(t_sim,u_s,'b', ...
         t_sim,u_P,'r', ...
         t_sim,u_PI,'k','LineWidth',lineWidth);
    grid on;

    title(sprintf('T_2/T_1=%g | RMS: %.3f / %.3f / %.3f', ...
        ratios_ex(n),rms(u_s),rms(u_P),rms(u_PI)));

    xlim([300 400]);
    xlabel('t');
    ylabel('u');

    if n==1
        legend('PI jednopętlowy','P kaskadowy', ...
            'PI kaskadowy','Location','best');
    end
end

title(tl1,'Odpowiedzi skokowe: układ jednopętlowy i kaskadowy');
title(tl2,'Sygnały sterujące: PI jednopętlowy, P i PI kaskadowy');
title(tl3,'Sygnały sterujące w oknie t=300...400');

%% FUNKCJA POMOCNICZA

function plotRatioMap(x,y,Dd,ratioMax)
    % Mapa ilorazu w skali log2 ze stałym zakresem [1/ratioMax, ratioMax].
    lim = log2(ratioMax);
    Z   = log2(Dd);
    Z   = max(min(Z,lim),-lim);          % nasycenie wartości spoza zakresu

    imagesc(x,y,Z);
    set(gca,'YDir','normal');
    colormap(gca,redblue_fixed(256));
    clim([-lim lim]);                    % biały = 1 zawsze w środku skali

    cb = colorbar;
    k  = floor(lim);
    tk = -k:k;                           % potęgi 2: 0.25, 0.5, 1, 2, 4
    cb.Ticks      = tk;
    cb.TickLabels = compose('%.3g',2.^tk);
end

function cmap = redblue_fixed(n)
    % Niebieski -> biały -> czerwony, biały dokładnie w środku.
    h = n/2;
    blue_part = [linspace(0,1,h)', linspace(0,1,h)', ones(h,1)];
    red_part  = [ones(h,1), linspace(1,0,h)', linspace(1,0,h)'];
    cmap = [blue_part; red_part];
end
