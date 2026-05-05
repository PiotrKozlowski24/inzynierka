s = tf('s');

T1 = 1;

T2_vals = linspace(5, 500,100);
L2_vals = linspace(1, 100, 20);

G_s = 1 / (T1*s + 1);

% Preallocate
riseTime      = zeros(length(T2_vals), length(L2_vals));
overshoot     = zeros(length(T2_vals), length(L2_vals));
settlingTime  = zeros(length(T2_vals), length(L2_vals));

for i = 1:length(T2_vals)
    for j = 1:length(L2_vals)

        T2 = T2_vals(i);
        L2 = L2_vals(j);

        % Use real delay
        G_p = tf(1, [T2 1], 'InputDelay', L2);
        G_total = G_s * G_p;

        % PID tuning (try PI first for stability)
        C = pidtune(G_total, 'PID');

        % Closed loop
        T_cl = feedback(C * G_total, 1);

        % Get step info
        info = stepinfo(T_cl);

        riseTime(i,j)     = info.RiseTime;
        overshoot(i,j)    = info.Overshoot;
        settlingTime(i,j) = info.SettlingTime;
    end
end

figure;
imagesc(L2_vals, T2_vals, riseTime);
set(gca,'YDir','normal');
colorbar;
title('Rise Time');
xlabel('L2 (Delay)');
ylabel('T2 (Time Constant)');

figure;
imagesc(L2_vals, T2_vals, overshoot);
set(gca,'YDir','normal');
colorbar;
title('Overshoot (%)');
xlabel('L2 (Delay)');
ylabel('T2');

figure;
imagesc(L2_vals, T2_vals, settlingTime);
set(gca,'YDir','normal');
colorbar;
title('Settling Time');
xlabel('L2');
ylabel('T2');

% KASKADA

C1 = pidtune(G_s, 'PID');
T_inner = feedback(C1 * G_s, 1);

% Preallocate
riseTime_c     = zeros(length(T2_vals), length(L2_vals));
overshoot_c     = zeros(length(T2_vals), length(L2_vals));
settlingTime_c  = zeros(length(T2_vals), length(L2_vals));

for i = 1:length(T2_vals)
    for j = 1:length(L2_vals)

        T2 = T2_vals(i);
        L2 = L2_vals(j);

        % Use real delay
        G_p = tf(1, [T2 1], 'InputDelay', L2);
        G_outer = T_inner * G_p;
        
        C2 = pidtune(G_outer, 'PID');
        
        % FULL SYSTEM
        T_cascade = feedback(C2 * G_outer, 1);

        % Get step info
        info = stepinfo(T_cascade);

        riseTime_c(i,j)     = info.RiseTime;
        overshoot_c(i,j)    = info.Overshoot;
        settlingTime_c(i,j) = info.SettlingTime;
    end
end

figure;
imagesc(L2_vals, T2_vals, riseTime_c);
set(gca,'YDir','normal');
colorbar;
title('Rise Time - cascade');
xlabel('L2 (Delay)');
ylabel('T2 (Time Constant)');

figure;
imagesc(L2_vals, T2_vals, overshoot_c);
set(gca,'YDir','normal');
colorbar;
title('Overshoot (%) - cascade');
xlabel('L2 (Delay)');
ylabel('T2');

figure;
imagesc(L2_vals, T2_vals, settlingTime_c);
set(gca,'YDir','normal');
colorbar;
title('Settling Time - cascade');
xlabel('L2');
ylabel('T2');

% różnica 1-punktowe vs kaskada

riseTime_diff = riseTime - riseTime_c;
overshoot_diff = overshoot - overshoot_c;
settlingTime_diff = settlingTime - settlingTime_c;

figure;
imagesc(L2_vals, T2_vals, riseTime_diff);
set(gca,'YDir','normal');
colorbar;
title('Rise Time - cascade');
xlabel('L2 (Delay)');
ylabel('T2 (Time Constant)');

figure;
imagesc(L2_vals, T2_vals, overshoot_diff);
set(gca,'YDir','normal');
colorbar;
title('Overshoot (%) - cascade');
xlabel('L2 (Delay)');
ylabel('T2');

figure;
imagesc(L2_vals, T2_vals, settlingTime_diff);
set(gca,'YDir','normal');
colorbar;
title('Settling Time - cascade');
xlabel('L2');
ylabel('T2');