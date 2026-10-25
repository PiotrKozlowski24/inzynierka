%% PARAMETRY REGULATOROW W FUNKCJI T2/T1

clear;
clc;
close all;

%% Wczytanie wynikow symulacji
load('simulation_results.mat');

%% Ustawienia wykresow
nBins = 100;     % liczba przedzialow do wyznaczenia mediany
nShow = 2;      % liczba prezentowanych wartosci L2

nL = numel(L2_vals);

% Indeksy wybranych wartosci L2
L2_idx = unique(round(linspace(1, nL, nShow)));

% Kolory dla poszczegolnych wartosci L2
colors = lines(numel(L2_idx));

%% Obliczenie stosunku T2/T1
R = T2_vals(:) ./ T1_vals(:).';

% Przedzialy logarytmiczne
edges = logspace(log10(min(R(:))), ...
                 log10(max(R(:))), nBins+1);

% Srodki przedzialow
centers = sqrt(edges(1:end-1) .* edges(2:end));

% Przypisanie punktow do przedzialow
bin = discretize(R(:), edges);

%% Dane parametrow regulatorow
params = struct( ...
    'name', { ...
        'Kp — regulator PI jednopetlowy', ...
        'Ki — regulator PI jednopetlowy', ...
        'Kp — regulator PI zewnetrzny', ...
        'Ki — regulator PI zewnetrzny'}, ...
    'data', { ...
        Kp_single, ...
        Ki_single, ...
        Kp_outer, ...
        Ki_outer});

%% Tworzenie wykresow
figure('Color', 'w', ...
       'Position', [100 100 1100 850]);
tiledlayout(2, 2, ...
            'TileSpacing', 'compact', ...
            'Padding', 'compact');

for m = 1:numel(params)
    nexttile;
    hold on;
    grid on;
    box on;

    for c = 1:numel(L2_idx)
        k = L2_idx(c);

        % Dane dla wybranej wartosci L2
        A = squeeze(params(m).data(k, :, :));
        v = A(:);

        % Odrzucenie niepoprawnych danych
        ok = isfinite(v) & ~isnan(bin);

        % Wszystkie punkty pomiarowe
        scatter(R(ok), v(ok), 10, colors(c, :), ...
                'filled', ...
                'MarkerFaceAlpha', 0.35, ...
                'DisplayName', sprintf('L_2 = %.2f', L2_vals(k)));
    end

    % Os X w skali logarytmicznej
    set(gca, 'XScale', 'log');
    xlim([min(R(:)), max(R(:))]);
    xlabel('Stosunek T_2/T_1');
    ylabel(params(m).name);
    title(params(m).name);
    legend('Location', 'best');
end

%% Tytul calej figury
sgtitle('Parametry regulatorów PI oraz P-PI w funkcji T_2/T_1');