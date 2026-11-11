clc
clear
s = tf('s');

T1_vals = linspace(1, 20, 20);
T2_vals = linspace(20, 200, 20);
L2_vals = linspace(0, 60, 20);
nL = numel(L2_vals); nT2 = numel(T2_vals); nT1 = numel(T1_vals);

%% ===== WSPÓLNE KRYTERIUM STROJENIA =====
wc    = 0.02;      % [rad/s] pulsacja odcięcia pętli zewnętrznej (taka sama dla obu struktur)
k_in  = 2;         % pętla wewnętrzna kaskady: wc_in = k_in * wc
opts     = pidtuneOptions('CrossoverFrequency', wc);        % single-loop PI i zewn. PI w kaskadzie
opts_in  = pidtuneOptions('CrossoverFrequency', k_in*wc);   % wewn. P

%% Prealokacja (L2 x T2 x T1)
sz = [nL, nT2, nT1];
riseTime = zeros(sz); overshoot = zeros(sz); settlingTime = zeros(sz); ITAE = zeros(sz);
riseTime_c = zeros(sz); overshoot_c = zeros(sz); settlingTime_c = zeros(sz); ITAE_c = zeros(sz);
Kp_single = zeros(sz); Ki_single = zeros(sz);
Kp_inner  = zeros(sz); Kp_outer = zeros(sz); Ki_outer = zeros(sz);
PM_single = zeros(sz); PM_casc = zeros(sz);   % uzyskany zapas fazy (kontrola wykonalności wc)

%% Symulacje
t_sim = 0:0.1:2000;
totalSim = nL*nT2*nT1; simCount = 0; tic;

for k = 1:nL
    L2 = L2_vals(k);
    for i = 1:nT2
        T2 = T2_vals(i);
        G_p = tf(1, [T2 1], 'InputDelay', L2);
        for j = 1:nT1
            T1  = T1_vals(j);
            G_s = 1/(T1*s + 1);

            % ---- Single-loop PI (wc) ----
            G_total = G_s*G_p;
            [C, infoC] = pidtune(G_total, 'PI', opts);
            T_cl = feedback(C*G_total, 1);
            info = stepinfo(T_cl);
            riseTime(k,i,j) = info.RiseTime;
            overshoot(k,i,j) = info.Overshoot;
            settlingTime(k,i,j) = info.SettlingTime;
            Kp_single(k,i,j) = C.Kp;  Ki_single(k,i,j) = C.Ki;
            PM_single(k,i,j) = infoC.PhaseMargin;
            [y, t] = step(T_cl, t_sim);
            ITAE(k,i,j) = trapz(t, t.*abs(1 - y));

            % ---- Cascade: P (wewn., k_in*wc) + PI (zewn., wc) ----
            C1 = pidtune(G_s, 'P', opts_in);
            T_inner = feedback(C1*G_s, 1);
            G_outer = T_inner*G_p;
            [C2, infoC2] = pidtune(G_outer, 'PI', opts);
            T_cascade = feedback(C2*G_outer, 1);
            info_c = stepinfo(T_cascade);
            riseTime_c(k,i,j) = info_c.RiseTime;
            overshoot_c(k,i,j) = info_c.Overshoot;
            settlingTime_c(k,i,j) = info_c.SettlingTime;
            Kp_inner(k,i,j) = C1.Kp;
            Kp_outer(k,i,j) = C2.Kp;  Ki_outer(k,i,j) = C2.Ki;
            PM_casc(k,i,j) = infoC2.PhaseMargin;
            [yc, tc] = step(T_cascade, t_sim);
            ITAE_c(k,i,j) = trapz(tc, tc.*abs(1 - yc));

            % Postęp
            simCount = simCount + 1;
            eta = (totalSim - simCount) * toc/simCount;
            fprintf('\rProgress: %6.2f %% | %d / %d | ETA: %s', ...
                100*simCount/totalSim, simCount, totalSim, datestr(seconds(eta),'HH:MM:SS'));
        end
    end
end

%% Zapis
save('simulation_results_wc.mat', ...
    'riseTime','overshoot','settlingTime','ITAE', ...
    'riseTime_c','overshoot_c','settlingTime_c','ITAE_c', ...
    'Kp_single','Ki_single','Kp_inner','Kp_outer','Ki_outer', ...
    'PM_single','PM_casc','T1_vals','T2_vals','L2_vals','wc','k_in');
fprintf('\nResults saved to simulation_results_wc.mat\n');