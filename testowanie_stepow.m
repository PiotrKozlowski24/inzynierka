L2 = 5;

% Define 3 test cases (each row = one test)
T_values = [
    55 500;
    30 485;
    100 460
];

t = 0:0.01:1000;

for i = 1:size(T_values,1)

    figure;   
    hold on;
    grid on;

    T1 = T_values(i,1);
    T2 = T_values(i,2);

    % --- PLANT ---
    G_s = tf(1, [T1 1]);
    G_p = tf(1, [T2 1], 'InputDelay', L2);
    G_total = G_s * G_p;

    % --- STANDARD PID ---
    C = pidtune(G_total, 'PID');
    T_cl = feedback(C * G_total, 1);
    y1 = step(T_cl, t);

    % --- CASCADE ---
    C1 = pidtune(G_s, 'PID');
    T_inner = feedback(C1 * G_s, 1);

    G_outer = T_inner * G_p;
    C2 = pidtune(G_outer, 'PID');
    T_cascade = feedback(C2 * G_outer, 1);
    y2 = step(T_cascade, t);

    % --- PLOT ---
    plot(t, y1, '--', 'DisplayName', 'Normal');
    plot(t, y2, 'LineWidth', 1.5, 'DisplayName', 'Cascade');

    xlabel('Time (s)');
    ylabel('Response');
    title(sprintf('Step Response (T1=%d, T2=%d)', T1, T2));
    legend;
end