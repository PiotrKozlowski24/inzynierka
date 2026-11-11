%% ---- Analiza wskaźników vs T2/T1 (4 wykresy 1D, 4 przykładowe opóźnienia) ----
% Zastępuje całą sekcję "Analysis vs T2/T1 ratio" ze skryptu.
% Wymaga zmiennych z simulation_results.mat (wczytywane poniżej).

load("simulation_results_wc_wcin5.mat");
nL = numel(L2_vals);

%% Parametry
nBins = 20;                                % liczba binów (skala log)

% >>> TU WPISZ WYBRANE OPÓŹNIENIA L2 <<<
L2_chosen = [0 2 10 30 60];                  % dowolna liczba wartości
% L2_chosen = [];                          % pusta lista = 4 równomiernie z przekroju

if isempty(L2_chosen)
    L2_idx = unique(round(linspace(1, nL, 4)));
else
    L2_idx = zeros(size(L2_chosen));
    for q = 1:numel(L2_chosen)
        [dmin, L2_idx(q)] = min(abs(L2_vals(:) - L2_chosen(q)));
        if dmin > 1e-9
            warning('L2 = %g nie ma w danych, użyto najbliższego: %g', ...
                L2_chosen(q), L2_vals(L2_idx(q)));
        end
    end
    L2_idx = unique(L2_idx, 'stable');     % usuwa duplikaty, zachowuje kolejność
end
colors = lines(numel(L2_idx));
%% Metryki: kaskada vs jednopunktowa
% isRatio = true  -> iloraz kaskada / jednopunktowa (1 = brak różnicy)
% isRatio = false -> różnica kaskada - jednopunktowa [p.p.] (0 = brak różnicy);
%                    przeregulowanie bywa 0, więc iloraz byłby nieokreślony
metrics = struct( ...
    'title',   {'Czas narastania', 'Przeregulowanie', 'Czas regulacji', 'ITAE'}, ...
    'ylabel',  {'kaskada / jednopunktowa', ...
                'P_{kaskada} - P_{jednopunktowa} [p.p.]', ...
                'kaskada / jednopunktowa', ...
                'kaskada / jednopunktowa'}, ...
    'isRatio', {true, false, true, true}, ...
    'single',  {riseTime,   overshoot,   settlingTime,   ITAE}, ...
    'cascade', {riseTime_c, overshoot_c, settlingTime_c, ITAE_c});

%% Oś X: T2/T1 dla każdej pary (nT2 x nT1), biny logarytmiczne
R       = T2_vals(:) ./ T1_vals(:).';
edges   = logspace(log10(min(R(:))), log10(max(R(:))), nBins + 1);
centers = sqrt(edges(1:end-1) .* edges(2:end));
bin     = discretize(R(:), edges);

%% Rysunek
figure('Color', 'w', 'Position', [100 100 1300 850]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for m = 1:numel(metrics)
    nexttile; hold on; grid on; box on;

    for c = 1:numel(L2_idx)
        k  = L2_idx(c);
        A  = squeeze(metrics(m).single(k, :, :));    % nT2 x nT1
        Ac = squeeze(metrics(m).cascade(k, :, :));

        if metrics(m).isRatio
            v = Ac ./ A;
            v(~isfinite(v) | v <= 0) = NaN;          % log osi Y wymaga dodatnich
        else
            v = Ac - A;
        end
        v  = v(:);
        ok = isfinite(v) & ~isnan(bin);

        % Pojedyncze punkty (blado) + mediana w binach (linia)
        scatter(R(ok), v(ok), 8, colors(c, :), 'filled', ...
                'MarkerFaceAlpha', 0.15, 'HandleVisibility', 'off');

        med = accumarray(bin(ok), v(ok), [nBins 1], @median, NaN);
        plot(centers, med, '-', 'LineWidth', 2, 'Color', colors(c, :), ...
             'DisplayName', sprintf('L_2 = %.2g', L2_vals(k)));
    end

    set(gca, 'XScale', 'log');
    if metrics(m).isRatio
        set(gca, 'YScale', 'log');
        yline(1, '--k', 'HandleVisibility', 'off');
    else
        yline(0, '--k', 'HandleVisibility', 'off');
    end

    xlim([min(R(:)) max(R(:))]);
    xlabel('T_2/T_1');
    ylabel(metrics(m).ylabel);
    title(metrics(m).title);
    legend('Location', 'best');
end

sgtitle('Kaskada vs. Jednopunktowa - Mediany ilorazów/różnicy wskaźników w funkcji T_2/T_1 dla różnych opóźnień L_2');
