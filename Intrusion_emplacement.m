% Thermomechanical visco-elasto-plastic numerical model 
% for trans-lithospheric mafic-ultramafic intrusion emplacement into the crust;
% equilibrium melt fraction for different rocks 
% is computed with external function 
% Melt_fraction.m;
% the model also account for erosion/sedimentation processes 
% and uses external functions 
% Stokes_Continuity_solver_sandbox.m, 
% Temperature_solver_grid.m
 
% Staggered Grid 
% 
%     vx       vx       vx    
%
% vy  T---vy---T---vy---T   vy
%     |        |        |
%     vx   P   vx   P   vx    
%     |        |        |
% vy  T---vy---T---vy---T   vy
%     |        |        |
%     vx   P   vx   P   vx    
%     |        |        |
% vy  T---vy---T---vy---T   vy
%
%     vx       vx       vx    
% 
% Lines show basic grid
% Ghost nodes shown outside the basic grid
% are used for boundary conditions

% Clearing all variables and arrays
clear;
% Clearing figures
clf;

% Temperature at the top, and bottom of the model, K
ttop=273;
tbottom=1600;


% Acceleration of Gravity, m/s^2
gx=0;
gy=9.81;

% Gas constant J/mol/K
RGAS=8.314;

% Initial model size, m
xsize0=100000;
ysize0=120000;
xsize=xsize0;
ysize=ysize0;
% Initial water level
waterlev0=8000;
waterlev=waterlev0;

% Defining grid resolution
xnum=201;
ynum=61;

% Viscosity limits for rocks, Pa
etamin=1e+14;   % Lower limit, Pa
etamax=1e+25;   % Upper limit, Pa
% Partally molten rock viscosity 
etamelt=1e+14; % Pa s
% Lower stress limit for power law, Pa
stressmin=1e+4;

% Viscoelastic timestep, s
timemax=1e+1*365.25*24*3600; % 100 year
% Maximal marker displacement step, number of gridsteps
markmax=0.1;
% Moving Markers: 
% 0 = not moving at all
% 1 = simple advection
% 4 = 4-th order in space  Runge-Kutta
markmove=1;
% Velocity calculation
% 0 = by Solving momentum and continuity equations
% 1 = solid body rotation
movemod=0;
% Maximal temperature change, allowed for one timestep, K
tempmax=30;
% Amount of timesteps
stepmax=10000;


% Topography model
% Topography model size in horizontal direction
tsize=xsize;
% Defining topography model resolution
tnum=301;
% Grid for topography profile
gridt=zeros(3,tnum);
tstp=tsize/(tnum-1); % topography grid step
gridt(1,1)=0; % beginning of topography profile
for i=2:1:tnum
    gridt(1,i)=gridt(1,i-1)+tstp;
end
% Topography diffusion koefficient Ks, m^2/s
% dYt/dt=Ks*d2Yt/dx^2
% Define dYt/dt - erosion rate
dYtdt=1/(1000*365.25*24*3600); % 1 mm/yr
% Define d2Yt - max elevation
d2Yt=10*1000; % 10 km
% Define dx - transport lengthscale
dx=100*1000; % 100 km
Ks=dYtdt*dx^2/d2Yt
topotime=zeros(1000,1);
topohigh=zeros(1000,tnum);
topowater=zeros(1000,1);


% Material properties
% MRHO = density (kg/m3): RHO*[1-ALP*(T-273)]*[1+BET*(P-1e+5)]
% MFLOW = power-law: EPSILONii=AD*SIGMAii^n*exp[-(Ea+Va*P)/RT)
% MMU = shear modulus (Pa)
% MPL = Brittle/plastic strength (Pa): SIGMAyeild=C+sin(FI)*P
%       C=C0, FI=FI0 for strain<=GAM0
%       C=C0+(C1-C0)/(GAM1-GAM0)*(strain-GAM0), FI=FI0+(FI1-FI0)/(GAM1-GAM0)*(strain-GAM0) for GAM0<strain<GAM1
%       C=C1, FI=FI1 for strain>=GAM0
% MCP = heat capacity (J/K/kg)
% MKT = thermal conductivity (W/m/K): k=k0+a/(T+77) 
% MHR = radiogenic heat production (W/m^3) 

% Materials
% 1 = Weak Layer ("sticky air/water")
MRHO(1,1)=1000;             % standard density, kg/m^3
MRHO(1,2)=0;                % thermal expansion, 1/K
MRHO(1,3)=0;                % compressibility, 1/Pa
MFLOW(1,1)=0;               % 0=constant viscosity
MFLOW(1,2)=1e+13;           % viscosity, Pa s
MMU(1)=1e+20;               % shear modulus, Pa
MPL(1,1)=0;                 % C0, Pa
MPL(1,2)=0;                 % C1, Pa
MPL(1,3)=0;                 % sin(FI0)
MPL(1,4)=0;                 % sin(FI1)
MPL(1,5)=0;                 % GAM0
MPL(1,6)=1;                 % GAM1
MCP(1)=3000;                % Cp, J/kg
MKT(1,1)=300;               % k0, W/m/K
MKT(1,2)=0;                 % a, W/m
MHR(1)=0;                   % radiogenic heat production, W/m^3
% 2 = Sediments
MRHO(2,1)=2700;             % standard density, kg/m^3
MRHO(2,2)=3e-5;             % thermal expansion, 1/K
MRHO(2,3)=1e-11;            % compressibility, 1/Pa
MRHO(2,4)=2400;             % melt density, kg/m^3
MFLOW(2,1)=1;               % 1=power law (wet quartzite: Ranalli, 1995)
MFLOW(2,2)=3.2e-4;          % AD, 1/s/MPa^n
MFLOW(2,3)=2.3;             % n
MFLOW(2,4)=154;             % Ea, kJ/mol
MFLOW(2,5)=0;               % Va, cm^3
MMU(2)=1e+10;               % shear modulus, Pa
MPL(2,1)=1e+6;              % C0, Pa
MPL(2,2)=1e+6;              % C1, Pa
MPL(2,3)=0.20;                 % sin(FI0)
MPL(2,4)=0.00;                 % sin(FI1)
MPL(2,5)=0;                 % GAM0
MPL(2,6)=0.1;                 % GAM1
MCP(2)=1000;                % Cp, J/kg
MKT(2,1)=0.64;              % k0, W/m/K
MKT(2,2)=807;               % a, W/m
MHR(2)=2.0e-6;              % radiogenic heat production, W/m^3
% 3 = Basalts
MRHO(3,1)=3000;             % standard density, kg/m^3
MRHO(3,2)=3e-5;             % thermal expansion, 1/K
MRHO(3,3)=1e-11;            % compressibility, 1/Pa
MRHO(3,4)=2400;             % melt density, kg/m^3
MFLOW(3,1)=1;               % 1=power law (wet quartzite: Ranalli, 1995)
MFLOW(3,2)=3.2e-4;          % AD, 1/s/MPa^n
MFLOW(3,3)=2.3;             % n
MFLOW(3,4)=154;             % Ea, kJ/mol
MFLOW(3,5)=0;               % Va, cm^3
MMU(3)=2.5e+10;             % shear modulus, Pa
MPL(3,1)=1e+6;              % C0, Pa
MPL(3,2)=1e+6;              % C1, Pa
MPL(3,3)=0.00;                 % sin(FI0)
MPL(3,4)=0.00;                 % sin(FI1)
MPL(3,5)=0;                 % GAM0
MPL(3,6)=0.1;                 % GAM1
MCP(3)=1000;                % Cp, J/kg
MKT(3,1)=1.18;              % k0, W/m/K
MKT(3,2)=474;               % a, W/m
MHR(3)=2.5e-7;              % radiogenic heat production, W/m^3
% 4 = Gabbro
MRHO(4,1)=3000;             % standard density, kg/m^3
MRHO(4,2)=3e-5;             % thermal expansion, 1/K
MRHO(4,3)=1e-11;            % compressibility, 1/Pa
MRHO(4,4)=2700;             % melt density, kg/m^3
MFLOW(4,1)=1;               % 1=power law (plagioclase An75: Ranalli, 1995)
MFLOW(4,2)=3.3e-4;          % AD, 1/s/MPa^n
MFLOW(4,3)=3.2;             % n
MFLOW(4,4)=238;             % Ea, kJ/mol
MFLOW(4,5)=0;               % Va, cm^3
MMU(4)=2.5e+10;             % shear modulus, Pa
MPL(4,1)=1e+6;              % C0, Pa
MPL(4,2)=1e+6;              % C1, Pa
MPL(4,3)=0.2;               % sin(FI0)
MPL(4,4)=0.00;               % sin(FI1)
MPL(4,5)=0;                 % GAM0
MPL(4,6)=0.1;                 % GAM1
MCP(4)=1000;                % Cp, J/kg
MKT(4,1)=1.18;              % k0, W/m/K
MKT(4,2)=474;               % a, W/m
MHR(4)=2.5e-7;              % radiogenic heat production, W/m^3
% 5 = Lithospheric mantle
MRHO(5,1)=3300;             % standard density, kg/m^3
MRHO(5,2)=3e-5;             % thermal expansion, 1/K
MRHO(5,3)=1e-11;            % compressibility, 1/Pa
MRHO(5,4)=2700;             % melt density, kg/m^3
MFLOW(5,1)=1;               % 1=power law (dry olivine: Ranalli, 1995)
MFLOW(5,2)=2.5e+4;          % AD, 1/s/MPa^n
MFLOW(5,3)=3.5;             % n
MFLOW(5,4)=532;             % Ea, kJ/mol
MFLOW(5,5)=10;               % Va, cm^3
MMU(5)=6.7e+10;             % shear modulus, Pa
MPL(5,1)=1e+6;              % C0, Pa
MPL(5,2)=1e+6;              % C1, Pa
MPL(5,3)=0.6;               % sin(FI0)
MPL(5,4)=0.00;               % sin(FI1)
MPL(5,5)=0;                 % GAM0
MPL(5,6)=0.1;                 % GAM1
MCP(5)=1000;                % Cp, J/kg
MKT(5,1)=0.73;              % k0, W/m/K
MKT(5,2)=1293;              % a, W/m
MHR(5)=2.2e-8;              % radiogenic heat production, W/m^3
% 6 = Asthenospheric mantle
MRHO(6,1)=3300;             % standard density, kg/m^3
MRHO(6,2)=3e-5;             % thermal expansion, 1/K
MRHO(6,3)=1e-11;            % compressibility, 1/Pa
MRHO(6,4)=2700;             % melt density, kg/m^3
MFLOW(6,1)=1;               % 1=power law (dry olivine: Ranalli, 1995)
MFLOW(6,2)=2.5e+4;          % AD, 1/s/MPa^n
MFLOW(6,3)=3.5;             % n
MFLOW(6,4)=532;             % Ea, kJ/mol
MFLOW(6,5)=10;               % Va, cm^3
MMU(6)=6.7e+10;             % shear modulus, Pa
MPL(6,1)=1e+6;              % C0, Pa
MPL(6,2)=1e+6;              % C1, Pa
MPL(6,3)=0.6;               % sin(FI0)
MPL(6,4)=0.00;               % sin(FI1)
MPL(6,5)=0;                 % GAM0
MPL(6,6)=0.1;                 % GAM1
MCP(6)=1000;                % Cp, J/kg
MKT(6,1)=0.73;              % k0, W/m/K
MKT(6,2)=1293;              % a, W/m
MHR(6)=2.2e-8;              % radiogenic heat production, W/m^3
% 7 = Hydrated mantle in the intra-plate fracture zone
MRHO(7,1)=3300;             % standard density, kg/m^3
MRHO(7,2)=3e-5;             % thermal expansion, 1/K
MRHO(7,3)=1e-11;            % compressibility, 1/Pa
MRHO(7,4)=2700;             % melt density, kg/m^3
MFLOW(7,1)=1;               % 1=power law (wet olivine: Ranalli, 1995)
MFLOW(7,2)=2.0e+3;          % AD, 1/s/MPa^n
MFLOW(7,3)=4.0;             % n
MFLOW(7,4)=471;             % Ea, kJ/mol
MFLOW(7,5)=0;               % Va, cm^3
MMU(7)=6.7e+10;             % shear modulus, Pa
MPL(7,1)=1e+6;              % C0, Pa
MPL(7,2)=1e+6;              % C1, Pa
MPL(7,3)=0.0;                 % sin(FI0)
MPL(7,4)=0.0;                 % sin(FI1)
MPL(7,5)=0;                 % GAM0
MPL(7,6)=0.1;                 % GAM1
MCP(7)=1000;                % Cp, J/kg
MKT(7,1)=0.73;              % k0, W/m/K
MKT(7,2)=1293;              % a, W/m
MHR(7)=2.2e-8;              % radiogenic heat production, W/m^3
% 8 = Upper continental crust (granodiorite)
MRHO(8,1)=2700;             % standard density, kg/m^3
MRHO(8,2)=3e-5;             % thermal expansion, 1/K
MRHO(8,3)=1e-11;            % compressibility, 1/Pa
MRHO(8,4)=2400;             % melt density, kg/m^3
MFLOW(8,1)=1;               % 1=power law (wet quartzite: Ranalli, 1995)
MFLOW(8,2)=3.2e-4;          % AD, 1/s/MPa^n
MFLOW(8,3)=2.3;             % n
MFLOW(8,4)=154;             % Ea, kJ/mol
MFLOW(8,5)=0;               % Va, cm^3
MMU(8)=1e+10;               % shear modulus, Pa
MPL(8,1)=1e+6;              % C0, Pa
MPL(8,2)=1e+6;              % C1, Pa
MPL(8,3)=0.2;                 % sin(FI0)
MPL(8,4)=0.00;                 % sin(FI1)
MPL(8,5)=0;                 % GAM0
MPL(8,6)=0.1;                 % GAM1
MCP(8)=1000;                % Cp, J/kg
MKT(8,1)=0.64;              % k0, W/m/K
MKT(8,2)=807;               % a, W/m
MHR(8)=1.0e-6;              % radiogenic heat production, W/m^3
% 9 = Lower oceanic crust (diorite)
MRHO(9,1)=3000;             % standard density, kg/m^3
MRHO(9,2)=3e-5;             % thermal expansion, 1/K
MRHO(9,3)=1e-11;            % compressibility, 1/Pa
MRHO(9,4)=2700;             % melt density, kg/m^3
MFLOW(9,1)=1;               % 1=power law (plagioclase An75: Ranalli, 1995)
MFLOW(9,2)=3.3e-4;          % AD, 1/s/MPa^n
MFLOW(9,3)=3.2;             % n
MFLOW(9,4)=238;             % Ea, kJ/mol
MFLOW(9,5)=0;               % Va, cm^3
MMU(9)=2.5e+10;             % shear modulus, Pa
MPL(9,1)=1e+6;              % C0, Pa
MPL(9,2)=1e+6;              % C1, Pa
MPL(9,3)=0.2;               % sin(FI0)
MPL(9,4)=0.00;               % sin(FI1)
MPL(9,5)=0;                 % GAM0
MPL(9,6)=0.1;                 % GAM1
MCP(9)=1000;                % Cp, J/kg
MKT(9,1)=1.18;              % k0, W/m/K
MKT(9,2)=474;               % a, W/m
MHR(9)=5.0e-7;              % radiogenic heat production, W/m^3

% Numerical Subgrid stress diffusion coefficient
dsubgrids=1;
% Numerical Subgrid temperature diffusion coefficient
dsubgridt=1;
% Shear heating on(1)/off(0)
frictyn=1;
% Adiabatic heating on(1)/off(0)
adiabyn=1;

% Pressure boundary conditions
% prfirst(1) = boundary condition mode:
% 0 - pressure in one cell definition
% 1 - pressure at the top and in the bottom of the channel
prfirst(1)=0;
% prfirst(2) = boundary condition value
prfirst(2)=1e+5;


% Velocity Boundary condition specified by bleft,bright,btop,bbot 
% are implemented from ghost nodes 
% directly into Stokes and continuity equations

% Upper, Lower boundaries: Free slip + Prescribed inward velocity (vertical shortening)
for j=1:1:xnum+1
    % Upper boundary: Free slip
    % vx(1,j)=btop(j,1)+vx(2,j)*btop(j,2)
    btop(j,1)=0;
    btop(j,2)=1;
    % vy(1,j)=btop(j,3)+vy(2,j)*btop(j,4)
    btop(j,3)=0;
    btop(j,4)=0;
    % Lower boundary: Free Slip  
    % vx(ynum+1,j)=bbottom(j,1)+vx(ynum,j)*bbottom(j,2)
    bbottom(j,1)=0;
    bbottom(j,2)=1;
    % vy(ynum,j)=bbottom(j,3)+vy(ynum-1,j)*bbottom(j,4)
    bbottom(j,3)=0;
    bbottom(j,4)=0;
end

% Left, Right boundaries: + Prescribed outward velocity (horizontal extension)
for i=1:1:ynum+1
    % Left boundary: Free slip   
    % vx(i,1)=bleft(i,1)+vx(i,2)*bleft(i,2)
    bleft(i,1)=0;
    bleft(i,2)=0;
    % vy(i,1)=bleft(i,3)+vy(i,2)*bleft(i,42)
    bleft(i,3)=0;
    bleft(i,4)=1;
    % Right boundary: Free slip 
    % vx(i,xnum)=bright(i,1)+vx(i,xnum-1)*bbright(i,2)
    bright(i,1)=0;
    bright(i,2)=0;
    % vy(i,xnum+1)=bright(i,3)+vx(i,xnum)*bbright(i,4)
    bright(i,3)=0;
    bright(i,4)=1;
end

% Internal boundary condition: prescribed velocity of "mobile wall"
bintern(1)=-1;      % Horizontal position of vx nodes with prescrbed velocity (no susch condition if negative)
bintern(2)=0;       % Min vertical position
bintern(3)=0;       % Max vertical position
bintern(4)=-0;      % Prescribed shortening velocity, m/s 
bintern(5)=-1;      % Horizontal position of vy nodes with prescrbed velocity (no susch condition if negative)
bintern(6)=0;       % Min vertical position
bintern(7)=0;       % Max vertical position
bintern(8)=0;       % Prescribed vertical velocity, m/s

% Defining average initial gridsteps
xstp=xsize./(xnum-1);
ystp=ysize./(ynum-1);

% Defining gridline positions for irregular basic grid

% Horizontal grid
gridx=zeros(xnum,1);
for i=2:1:xnum
    gridx(i)=gridx(i-1)+xstp;
end

% Vertical grid
b=1000; % grid spacing in high resolution area
nn=31;  % number of nodes in high resolution area
gridy=zeros(ynum,1);
% Define regular step in high resolution area
for i=2:1:nn
    gridy(i)=gridy(i-1)+b;
end
% Define factor of grid spacing increase from the bottom
% of high resolution area
D=ysize-gridy(nn); % distance to be covered by non-uniform grid
N=ynum-nn; % number of grid steps to be used in the grid
% Iterative search of F
F=1.1;
for i=1:1:100
    F=(1+D./b.*(1-1/F)).^(1/N);
end
% Define position of nodal points
for i=nn+1:1:ynum
    gridy(i)=gridy(i-1)+b*F.^(i-nn);
end
gridy(ynum)=ysize;

% Thermal boundary conditions
% Upper, Lower boundaries: constant temperature
for j=1:1:xnum
    % Upper boundary
    % tk(1,j)=btopt(j,1)+tk(2,j)*btop(j,2)
    btopt(j,1)=ttop;
    btopt(j,2)=0;
    % Lower boundary
    % tk(ynum,j)=bbottomt(j,1)+tk(ynum-1,j)*bbottomt(j,2)
    bbottomt(j,1)=tbottom;
    bbottomt(j,2)=0;
end
% Left, Right boundaries: symmetry
for i=1:1:ynum
    % Left boundary
    % tk(i,1)=bleftt(i,1)+bleftt(i,2)*tk(i,2);
    bleftt(i,1)=0;
    bleftt(i,2)=1;
    % Right boundary
    % tk(i,xnum)=brightt(i,1)+brightt(i,2)*tk(i,xnum-1);
    brightt(i,1)=0;
    brightt(i,2)=1;
end


% Defining number of markers and steps between them in the horizontal and vertical direction
mxnum=400; %number of markers in horizontal direction
mxstep=xsize/mxnum; %step between markers in horizontal direction
mynum=480;  %number of markers in vertical direction   
mystep=ysize/mynum; %step between markers in vertical direction

% Creating markers arrays
MX=zeros(mynum*mxnum,1);   % X coordinate, m
MY=zeros(mynum*mxnum,1);   % Y coordinate, m
MTK=zeros(mynum*mxnum,1);  % Temperature, K
MI=zeros(mynum*mxnum,1);   % Type
MXN=zeros(mynum*mxnum,1);  % Horizontal index
MYN=zeros(mynum*mxnum,1);  % Vertical index
MSXX=zeros(mynum*mxnum,1);  % SIGMAxx - deviatoric normal stress, Pa
MSXY=zeros(mynum*mxnum,1);  % SIGMAyy - shear stress, Pa
META=zeros(mynum*mxnum,1);  % viscosity, Pa s
MEXX=zeros(mynum*mxnum,1);  % EPSILONxx - normal strain rate, 1/s
MEXY=zeros(mynum*mxnum,1);  % EPSILONyy - shear strain rate, 1/s
MPR=zeros(mynum*mxnum,1);   % Pressure, Pa
MBII=zeros(mynum*mxnum,1);  % Accumulated bulk strain
MGII=-1e-20*ones(mynum*mxnum,1);  % Accumulated plastic strain
MRAT=ones(mynum*mxnum,1);   % EiiMarker/EiiGrid Ratio
MXM=zeros(mynum*mxnum,1);   % Melt fraction

% Defining intial position of markers
% Defining lithological structure of the model
% Marker counter
mm1=0;
for xm = 1:1:mxnum
    for ym = 1:1:mynum
        
        % Update marker counter:
        mm1=mm1+1;
        
        % Coordinates with small random displacement
        MX(mm1)=xm*mxstep-mxstep/2+(rand-0.5)*mxstep;
        MY(mm1)=ym*mystep-mystep/2+(rand-0.5)*mystep;
        
        % Initial rock distribution
        % 6 = Asthenosphere
        MI(mm1)=6;
        % 1 = Sticky air/water (8-11 km)
        if(MY(mm1)<7000)
            MI(mm1)=1;
        end
        % Upper crust with sediments
        % 8 = upper continental crust 
        if(MY(mm1)>=7000 && MY(mm1)<32000) 
            MI(mm1)=8;
        end
        % 2 = Sediments
        if(MY(mm1)>=7000 && MY(mm1)<=9000)
            MI(mm1)=2;
        end
        if(MY(mm1)>=11000 && MY(mm1)<=13000)
            MI(mm1)=2;
        end
        if(MY(mm1)>=15000 && MY(mm1)<=17000)
            MI(mm1)=2;
        end
        if(MY(mm1)>=19000 && MY(mm1)<=21000)
            MI(mm1)=2;
        end
        if(MY(mm1)>=23000 && MY(mm1)<=25000)
            MI(mm1)=2;
        end
        if(MY(mm1)>=27000 && MY(mm1)<=29000)
            MI(mm1)=2;
        end
        % 5 = Lithosphere 
        if(MY(mm1)>=32000 && MY(mm1)<95000) 
            MI(mm1)=5;
        end


       
        % Initial temperature structure
        % Adiabatic temperature gradient in the asthenosphere = 0.5 K/km
        dtdy=0.5/1000; % K/m
        MTK(mm1)=tbottom-dtdy*(ysize-MY(mm1));
        % Sticky water
        if(MI(mm1)==1)
            MTK(mm1)=ttop;
        end
        % Linear sectionned geotherm  
        yast=100000; % Bottom of the lithosphere
        tast=tbottom-dtdy*(ysize-yast); % T (K) of asthenosphere at y=yast
        ymoho=32000; % Bottom of the crust
        tmoho=900; % T (K) of the crust at y=ymoho
        % Mantle lithosphere
        if(MY(mm1)>ymoho && MY(mm1)<yast)
            MTK(mm1)=tmoho+(tast-tmoho)*(MY(mm1)-ymoho)/(yast-ymoho);
        end
        % Crust
        if(MY(mm1)>7000 && MY(mm1)<ymoho)
            MTK(mm1)=ttop+(tmoho-ttop)*(MY(mm1)-7000)/(ymoho-7000);
        end
        
        % Intrusion
        tintrus=1700; % Intrusion temperature
        dxchan=3000;  % magmatic channel width, m
        basalt=25; % Percent of enrichment by basaltic melt in the channel 
        % 7,3 = magmatic channel with percolating basaltic melt
        if(MX(mm1)>xsize/2-dxchan/2 && MX(mm1)<xsize/2+dxchan/2 && MY(mm1)>=30000 && MY(mm1)<100000) 
            % Basalt probability
            if(rand*100<basalt)
                MI(mm1)=3;
            else
                MI(mm1)=7;
            end
            MTK(mm1)=tintrus;
        end
        if(MX(mm1)>xsize/2-(dxchan/2+(MY(mm1)-92000)) && MX(mm1)<xsize/2+(dxchan/2+(MY(mm1)-92000)) && MY(mm1)>=92000 && MY(mm1)<97000) 
            if(rand*100<basalt)
                MI(mm1)=3;
            else
                MI(mm1)=7;
            end
            MTK(mm1)=tintrus;
        end

        % distance from the source center
        sradius=10000; % Source radius 
        dx=MX(mm1)-xsize/2;
        dy=MY(mm1)-(95000+sradius);
        dx=(dx^2+dy^2)^0.5;
        if(dx<sradius) 
            MI(mm1)=7;
            MTK(mm1)=tintrus;
        end
    end
end

% Save Number of markers
marknum=mm1

% Initial elevation for topography profile
for i=1:1:tnum
    % Above continental crust
    gridt(2,i)=7000;
end
% Save initial topography
topotime(1,1)=0;
topohigh(1,:)=gridt(2,:);
topowater(1,1)=waterlev;


% Density, viscosity, shear modulus, temperature, thermal conductivity, RHO*Cp arrays
etas1 = zeros(ynum,xnum);       % Viscosity for shear stress
etan1 = zeros(ynum-1,xnum-1);   % Viscosity for normal stress
mus1 = zeros(ynum,xnum);        % Shear modulus for shear stress
mun1 = zeros(ynum-1,xnum-1);    % Shear modulus for normal stress
sxy1 = zeros(ynum,xnum);        % Shear stress
sxx1 = zeros(ynum-1,xnum-1);    % Normal stress
rho1 = zeros(ynum,xnum);        % Density
tk1 = zeros(ynum,xnum);         % Old temperature
tk2=tk1;                        % New temperature
rhocp1 = zeros(ynum,xnum);      % RHO*Cp (for temperature equation)
kt1 = zeros(ynum,xnum);         % Thermal conductivity
hr1 = zeros(ynum,xnum);         % Radiogenic heat production
ha1 = zeros(ynum,xnum);         % Adiabatic heat production/consuming

% Initial time, s
timesum=0;
timestepd=timemax

% Main Time cycle
for ntimestep=1:1:stepmax
    
    % Defining viscoelastic timestep
    timestep=timemax % viscoelastic timestep
    % Plastic yeilding mark
    plastyn=0;

    % Backup transport properties arrays
    etas0 = etas1;
    etan0 = etan1;
    mus0 = mus1;
    mun0 = mun1;
    sxy0 = sxy1;
    sxx0 = sxx1;
    rho0 = rho1;
    tk0=tk2;
    rhocp0=rhocp1;
    kt0=kt1;
    hr0=hr1;
    ha0=ha1;
    % Clear transport properties arrays
    etas1 = zeros(ynum,xnum);
    etan1 = zeros(ynum-1,xnum-1);
    mus1 = zeros(ynum,xnum);
    mun1 = zeros(ynum-1,xnum-1);
    sxy1 = zeros(ynum,xnum);
    sxx1 = zeros(ynum-1,xnum-1);
    rho1 = zeros(ynum,xnum);
    tk1 = zeros(ynum,xnum);
    rhocp1 = zeros(ynum,xnum);
    kt1 = zeros(ynum,xnum);
    hr1 = zeros(ynum,xnum);
    ha1 = zeros(ynum,xnum);
    % Clear wights for basic nodes
    wtnodes=zeros(ynum,xnum);
    % Clear wights for etas
    wtetas=zeros(ynum,xnum);
    % Clear wights for etan
    wtetan=zeros(ynum-1,xnum-1);

    % Computing grid steps for basic nodes
    xstp1=zeros(xnum-1,1);
    ystp1=zeros(ynum-1,1);
    for i=1:1:xnum-1
        xstp1(i)=gridx(i+1)-gridx(i);
    end
    for i=1:1:ynum-1
        ystp1(i)=gridy(i+1)-gridy(i);
    end  

    % Computing grids and grid steps for Vx, Vy nodes
    % Horizontal (for Vy)
    gridcx=zeros(xnum+1,1);
    xstpc1=zeros(xnum,1);
    % Vertical (for Vx)
    gridcy=zeros(ynum+1,1);
    ystpc1=zeros(ynum,1);
    % First and last nodes and steps (for external nodes)
    % Horizontal (for Vy)
    gridcx(1)=gridx(1)-xstp1(1)/2;
    xstpc1(1)=xstp1(1);
    gridcx(xnum+1)=gridx(xnum)+xstp1(xnum-1)/2;
    xstpc1(xnum)=xstp1(xnum-1);
    % Vertical (for Vx)
    gridcy(1)=gridy(1)-ystp1(1)/2;
    ystpc1(1)=ystp1(1);
    gridcy(ynum+1)=gridy(ynum)+ystp1(ynum-1)/2;
    ystpc1(ynum)=ystp1(ynum-1);
    % Internal nodes
    for i=2:1:xnum
        gridcx(i)=(gridx(i)+gridx(i-1))/2;
    end
    for i=2:1:ynum
        gridcy(i)=(gridy(i)+gridy(i-1))/2;
    end   
    % Internal grid steps
    for i=2:1:xnum-1
        xstpc1(i)=(gridx(i+1)-gridx(i-1))/2;
    end
    for i=2:1:ynum-1
        ystpc1(i)=(gridy(i+1)-gridy(i-1))/2;
    end   

    % Interpolating parameters from markers to nodes
    for mm1 = 1:1:marknum

        % Check markers inside the grid
        if (MX(mm1)>=gridx(1) && MX(mm1)<=gridx(xnum) && MY(mm1)>=gridy(1) && MY(mm1)<=gridy(ynum)) 
            
            % Erosion-sedimentation
            % Find topography node for the marker
            xn=double(int16((MX(mm1)-gridt(1,1))/tstp-0.5))+1;
            if (xn<1)
                xn=1;
            end
            if (xn>tnum-1)
                xn=tnum-1;
            end
            % Compute relative distance to topography node
            dx=(MX(mm1)-gridt(1,xn))/tstp;
            % Compute topograhy elevation above the marker
            dy=gridt(2,xn)*(1-dx)+gridt(2,xn+1)*dx;
            % water/air to sediments transformation
            if (MI(mm1)==1 && MY(mm1)>dy)
                MI(mm1)=2; % Change marker type
                MRAT(mm1)=1; % Reset strain rate ratio
                MGII(mm1)=0; % Reset strain
            end
            % Rocks to water/air transformation
            if (MI(mm1)>1 && MY(mm1)<dy)
                MI(mm1)=1; % Change marker type
                MRAT(mm1)=1; % Reset strain rate ratio
                MGII(mm1)=0; % Reset strain
            end
           
            
            %  xn    rho(xn,yn)--------------------rho(xn+1,yn)
            %           ?           ^                  ?
            %           ?           ?                  ?
            %           ?          dy                  ?
            %           ?           ?                  ?
            %           ?           v                  ?
            %           ?<----dx--->o Mrho(xm,ym)       ?
            %           ?                              ?
            %           ?                              ?
            %  xn+1  rho(xn,yn+1)-------------------rho(xn+1,yn+1)
            %
            % Define indexes for upper left node in the cell where the marker is
            % using bisection
            % Find horizontal index
            xnmin=1;
            xnmax=xnum;
            while ((xnmax-xnmin)>1)
                % !!! SUBTRACT 0.5 since int16(0.5)=1
                xn=double(int16((xnmax+xnmin)./2-0.5));
                if(gridx(xn)>MX(mm1))
                    xnmax=xn;
                else
                    xnmin=xn;
                end
            end
            xn=xnmin;
            % Check horizontal index
            if (xn<1)
                xn=1;
            end
            if (xn>xnum-1)
                xn=xnum-1;
            end
            % Save horizontal index
            MXN(mm1)=xn;

            % Find vertical index
            ynmin=1;
            ynmax=ynum;
            while ((ynmax-ynmin)>1)
                % !!! SUBTRACT 0.5 since int16(0.5)=1
                yn=double(int16((ynmax+ynmin)./2-0.5));
                if(gridy(yn)>MY(mm1))
                    ynmax=yn;
                else
                    ynmin=yn;
                end
            end
            yn=ynmin;
            % Check vertical index
            if (yn<1)
                yn=1;
            end
            if (yn>ynum-1)
                yn=ynum-1;
            end
            % Save Vertical index
            MYN(mm1)=yn;

            % Define normalized distances from marker to the upper left node;
            dx=(MX(mm1)-gridx(xn))./xstp1(xn);
            dy=(MY(mm1)-gridy(yn))./ystp1(yn);

            % Compute marker weight koefficient from cell dimensions
            % Number of markers in a cell is in invert proportion to the cell volume
            mwt=1;%/xstp1(xn)/ystp1(yn);

            % Compute density from marker temperature
            MRHOCUR=MRHO(MI(mm1),1)*(1-MRHO(MI(mm1),2)*(MTK(mm1)-273))*(1+MRHO(MI(mm1),3)*(MPR(mm1)-1e+5));

            % Compute rho*Cp for marker 
            MRHOCPCUR=MRHOCUR*MCP(MI(mm1));
            
            % Change density for "air"
            if (MI(mm1)==1 && MY(mm1)<waterlev)
                MRHOCUR=1;
            end

            % Compute thermal conductivity from marker temperature
            % Rock thermal conductivity (W/m/K): k=k0+a/(T+77)
            MKTCUR=MKT(MI(mm1),1)+MKT(MI(mm1),2)/(MTK(mm1)+77);
            
            % Compute adiabatic heating term (alp*T*DP/Dt)
            MHACUR=MRHO(MI(mm1),2)*MTK(mm1);

            % Computing Marker Viscosity
            if(MFLOW(MI(mm1),1)==0)
                % Constant viscosity
                METACUR=MFLOW(MI(mm1),2);
            else
                % Power-law: EPSILONii=AD*SIGMAii^n*exp[-(Ea+Va*P)/RT)
                % Iterate for viscosity
                % First viscosity value
                % Compute and check old marker stress invariant in Pa
                sii0=(MSXX(mm1)^2+MSXY(mm1)^2)^0.5;
                % Check old marker stress invariant (should be allways positive to be used in power law)
                if(sii0<stressmin)
                    sii0=stressmin;
                end
                % Check marker temperature
                plawexp=MTK(mm1);
                if(plawexp<ttop)
                    plawexp=ttop;
                end
                % Compute exponential term: 
                % Ea is in J/mol(=1000*kJ/mol)
                % Va is in J/Pa (=1e-6*cm^3) 
                % Cut if too big (at cold temperature);
                plawexp=(MFLOW(MI(mm1),4)*1000+MFLOW(MI(mm1),5)*1e-6*MPR(mm1))/RGAS/plawexp;
                if(plawexp>150)
                    plawexp=150;
                end
                % Compute AD*exp[-Ea/RT)
                plawexp=MFLOW(MI(mm1),2)*exp(-plawexp);
                % Compute strain rate invariant from power law
                eii0=plawexp*(1e-6*sii0)^MFLOW(MI(mm1),3);
                % Compute effective viscosity
                eta0=sii0/2/eii0;
                % Forcasting second invariant of future marker stress for given viscoelastic timestep
                xelvis=eta0/(MMU(MI(mm1))*timestep+eta0);
                sxxnew=MSXX(mm1)*xelvis+2*eta0*MEXX(mm1)*MRAT(mm1)*(1-xelvis);
                sxynew=MSXY(mm1)*xelvis+2*eta0*MEXY(mm1)*MRAT(mm1)*(1-xelvis);
                sii1=(sxxnew^2+sxynew^2)^0.5;
                % Check new marker stress invariant (should be allways positive to be used in power law)
                if(sii1<stressmin)
                    sii1=stressmin;
                end
                % Compute strain rate invariant from power law
                eii1=plawexp*(1e-6*sii1)^MFLOW(MI(mm1),3);
                % Compute effective viscosity
                METACUR=sii1/2/eii1;
                % Iterate for viscosity which corresponds to future stress invariant using bisection
                % Iteration counter
                plawiter=0;
                while(plawiter<20 && abs(sii1-sii0)>1)
                    % Add iteration counter
                    plawiter=plawiter+1;
                    % Compute middle stress
                    siicur=(sii0+sii1)/2;
                    % Compute strain rate invariant from power law
                    eiicur=plawexp*(1e-6*siicur)^MFLOW(MI(mm1),3);
                    % Compute effective viscosity
                    METACUR=siicur/2/eiicur;
                    % Forcasting second invariant of future marker stress for given viscoelastic timestep
                    xelvis=METACUR/(MMU(MI(mm1))*timestep+METACUR);
                    sxxnew=MSXX(mm1)*xelvis+2*METACUR*MEXX(mm1)*MRAT(mm1)*(1-xelvis);
                    sxynew=MSXY(mm1)*xelvis+2*METACUR*MEXY(mm1)*MRAT(mm1)*(1-xelvis);
                    siinew=(sxxnew^2+sxynew^2)^0.5;
                    % Changing bisection limits
                    if((sii0<sii1 && siicur<siinew) || (sii0>sii1 && siicur>siinew))
                        sii0=siicur;
                    else
                        sii1=siicur;
                    end
                end
                % Limiting viscosity for the power law
                if (METACUR<etamin) 
                    METACUR=etamin;
                end
                if (METACUR>etamax) 
                    METACUR=etamax;
                end
            end

            % Check if any plastic yeiding condition is present 
            if (ntimestep>1 && (MPL(MI(mm1),1)>0 || MPL(MI(mm1),3)>0))
                % Checking for plastic yeilding
                % Forcasting second invariant of future marker stress for given viscoelastic timestep
                xelvis=METACUR/(MMU(MI(mm1))*timestep+METACUR);
                sxxnew=MSXX(mm1)*xelvis+2*METACUR*MEXX(mm1)*MRAT(mm1)*(1-xelvis);
                sxynew=MSXY(mm1)*xelvis+2*METACUR*MEXY(mm1)*MRAT(mm1)*(1-xelvis);
                siinew=(sxxnew^2+sxynew^2)^0.5;
                % Checking yeilding criterion for strain weakening/hardening
                % C=C0, FI=FI0 for strain<=GAM0
                % C=C0+(C1-C0)/(GAM1-GAM0)*(strain-GAM0), FI=FI0+(FI1-FI0)/(GAM1-GAM0)*(strain-GAM0) for GAM0<strain<GAM1
                % C=C1, FI=FI1 for strain>=GAM0
                MCOHES=MPL(MI(mm1),1);
                MFRICT=MPL(MI(mm1),3);
                if (MGII(mm1)>=MPL(MI(mm1),6))
                    MCOHES=MPL(MI(mm1),2);
                    MFRICT=MPL(MI(mm1),4);
                end
                if (MGII(mm1)>MPL(MI(mm1),5) && MGII(mm1)<MPL(MI(mm1),6))
                    MCOHES=MPL(MI(mm1),1)+(MPL(MI(mm1),2)-MPL(MI(mm1),1))/(MPL(MI(mm1),6)-MPL(MI(mm1),5))*(MGII(mm1)-MPL(MI(mm1),5));
                    MFRICT=MPL(MI(mm1),3)+(MPL(MI(mm1),4)-MPL(MI(mm1),3))/(MPL(MI(mm1),6)-MPL(MI(mm1),5))*(MGII(mm1)-MPL(MI(mm1),5));
                end
                % Computing yelding stress for the marker
                siiyeld=MCOHES+MFRICT*MPR(mm1);
                if (siiyeld<0) 
                    siiyeld=0;
                end
                % Correcting rock properties for yeilding 
                if (siiyeld<siinew)
                    % Bringing marker stresses to yeilding stress
                    siiold=(MSXX(mm1)^2+MSXY(mm1)^2)^0.5;
                    MSXX(mm1)=MSXX(mm1)*siiyeld/siiold;
                    MSXY(mm1)=MSXY(mm1)*siiyeld/siiold;
                    % Bringing marker viscosity to yeilding stress
                    eiiold=MRAT(mm1)*(MEXX(mm1)^2+MEXY(mm1)^2)^0.5;
                    METACUR=siiyeld/2/eiiold;
                    % Limiting viscosity for the yeilding
                    if (METACUR<etamin) 
                        METACUR=etamin;
                    end
                    if (METACUR>etamax) 
                        METACUR=etamax;
                    end
                    % Mark that plastic yeildind occur
                    plastyn=1;
                    % Mark that plastic strain needs to be accumulated
                    MGII(mm1)=abs(MGII(mm1));
                else
                    % Reset plastic strain if no yelding
                    MGII(mm1)=-1e-20;
                end
            end

            % Compute 1/MU values (MU is shear modulus) 
            MMUCUR=1/MMU(MI(mm1));
            
            % Molten rocks
            [xmelt hlat]=Melt_fraction(MPR(mm1),MTK(mm1),MI(mm1));
            % Save marker melting
            if(timesum>0)
                MXM(mm1)=xmelt;
            end
            if(xmelt>0 && timesum>0)
                % Reset creep parameters for molten rocks                   
                MRAT(mm1)=1; % Reset strain rate ratio
                MGII(mm1)=0; % Reset strain
                % Viscosity of partially molten rocks
                if(xmelt>0.1)
                    METACUR=etamelt;
                end
                % Density
                MRHOCUR=MRHOCUR*((1-xmelt)+MRHO(MI(mm1),4)/MRHO(MI(mm1),1)*xmelt);
                % RHO*CP
                MRHOCPCUR=MRHOCPCUR*((1-xmelt)+MRHO(MI(mm1),4)/MRHO(MI(mm1),1)*xmelt);
                % Compute adiabatic heating term (alp*T*DP/Dt)
                MHACUR=MHACUR*((1-xmelt)+MRHO(MI(mm1),4)/MRHO(MI(mm1),1)*xmelt);
                % Latent heating: effective adiabatic term, RHOCP
                if(xmelt<1)
                    % Melting adiabatic term: alpham=-rho*(dHlat/dP)/T
                    % Numerical differentiation
                    dp=1000; % Pressure increment, Pa
                    [xmelt hlat0]=Melt_fraction(MPR(mm1)-dp,MTK(mm1),MI(mm1));
                    [xmelt hlat1]=Melt_fraction(MPR(mm1)+dp,MTK(mm1),MI(mm1));
                    MHACUR=MHACUR-(hlat1-hlat0)/(2.0*dp);
                    % Melting heat capacity term: cpm=dHlat/dT 
                    % Numerical differentiation 
                    dt=1.0; % Temperature increment, Pa
                    [xmelt hlat0]=Melt_fraction(MPR(mm1),MTK(mm1)-dt,MI(mm1));
                    [xmelt hlat1]=Melt_fraction(MPR(mm1),MTK(mm1)+dt,MI(mm1));
                    MRHOCPCUR=MRHOCPCUR+MRHOCUR*(hlat1-hlat0)/(2.0*dt);
                end
            end
            
            % Save marker viscosity
            META(mm1)=METACUR;

            % Add properties to 4 surrounding nodes
            rho1(yn,xn)=rho1(yn,xn)+(1.0-dx).*(1.0-dy).*MRHOCUR*mwt;
            tk1(yn,xn)=tk1(yn,xn)+(1.0-dx).*(1.0-dy).*MTK(mm1)*mwt;
            kt1(yn,xn)=kt1(yn,xn)+(1.0-dx).*(1.0-dy).*MKTCUR*mwt;
            rhocp1(yn,xn)=rhocp1(yn,xn)+(1.0-dx).*(1.0-dy).*MRHOCPCUR*mwt;
            hr1(yn,xn)=hr1(yn,xn)+(1.0-dx).*(1.0-dy).*MHR(MI(mm1))*mwt;
            ha1(yn,xn)=ha1(yn,xn)+(1.0-dx).*(1.0-dy).*MHACUR*mwt;
            wtnodes(yn,xn)=wtnodes(yn,xn)+(1.0-dx).*(1.0-dy)*mwt;

            rho1(yn+1,xn)=rho1(yn+1,xn)+(1.0-dx).*dy.*MRHOCUR*mwt;
            tk1(yn+1,xn)=tk1(yn+1,xn)+(1.0-dx).*dy.*MTK(mm1)*mwt;
            kt1(yn+1,xn)=kt1(yn+1,xn)+(1.0-dx).*dy.*MKTCUR*mwt;
            rhocp1(yn+1,xn)=rhocp1(yn+1,xn)+(1.0-dx).*dy.*MRHOCPCUR*mwt;
            hr1(yn+1,xn)=hr1(yn+1,xn)+(1.0-dx).*dy.*MHR(MI(mm1))*mwt;
            ha1(yn+1,xn)=ha1(yn+1,xn)+(1.0-dx).*dy.*MHACUR*mwt;
            wtnodes(yn+1,xn)=wtnodes(yn+1,xn)+(1.0-dx).*dy*mwt;

            rho1(yn,xn+1)=rho1(yn,xn+1)+dx.*(1.0-dy).*MRHOCUR*mwt;
            tk1(yn,xn+1)=tk1(yn,xn+1)+dx.*(1.0-dy).*MTK(mm1)*mwt;
            kt1(yn,xn+1)=kt1(yn,xn+1)+dx.*(1.0-dy).*MKTCUR*mwt;
            rhocp1(yn,xn+1)=rhocp1(yn,xn+1)+dx.*(1.0-dy).*MRHOCPCUR*mwt;
            hr1(yn,xn+1)=hr1(yn,xn+1)+dx.*(1.0-dy).*MHR(MI(mm1))*mwt;
            ha1(yn,xn+1)=ha1(yn,xn+1)+dx.*(1.0-dy).*MHACUR*mwt;
            wtnodes(yn,xn+1)=wtnodes(yn,xn+1)+dx.*(1.0-dy)*mwt;

            rho1(yn+1,xn+1)=rho1(yn+1,xn+1)+dx.*dy.*MRHOCUR*mwt;
            tk1(yn+1,xn+1)=tk1(yn+1,xn+1)+dx.*dy.*MTK(mm1)*mwt;
            kt1(yn+1,xn+1)=kt1(yn+1,xn+1)+dx.*dy.*MKTCUR*mwt;
            rhocp1(yn+1,xn+1)=rhocp1(yn+1,xn+1)+dx.*dy.*MRHOCPCUR*mwt;
            hr1(yn+1,xn+1)=hr1(yn+1,xn+1)+dx.*dy.*MHR(MI(mm1))*mwt;
            ha1(yn+1,xn+1)=ha1(yn+1,xn+1)+dx.*dy.*MHACUR*mwt;
            wtnodes(yn+1,xn+1)=wtnodes(yn+1,xn+1)+dx.*dy*mwt;

            % Add viscosity etas(), shear stress sxy(),shear modulus mus() and rock type typ() to 4 surrounding basic nodes
            % only using markers located at <=0.5 gridstep distances from nodes
            if(dx<=0.5 && dy<=0.5)
                etas1(yn,xn)=etas1(yn,xn)+(1.0-dx).*(1.0-dy).*METACUR*mwt;
                mus1(yn,xn)=mus1(yn,xn)+(1.0-dx).*(1.0-dy).*MMUCUR*mwt;
                sxy1(yn,xn)=sxy1(yn,xn)+(1.0-dx).*(1.0-dy).*MSXY(mm1)*mwt;
                wtetas(yn,xn)=wtetas(yn,xn)+(1.0-dx).*(1.0-dy)*mwt;
            end
            if(dx<=0.5 && dy>=0.5)
                etas1(yn+1,xn)=etas1(yn+1,xn)+(1.0-dx).*dy.*METACUR*mwt;
                mus1(yn+1,xn)=mus1(yn+1,xn)+(1.0-dx).*dy.*MMUCUR*mwt;
                sxy1(yn+1,xn)=sxy1(yn+1,xn)+(1.0-dx).*dy.*MSXY(mm1)*mwt;
                wtetas(yn+1,xn)=wtetas(yn+1,xn)+(1.0-dx).*dy*mwt;
            end
            if(dx>=0.5 && dy<=0.5)
                etas1(yn,xn+1)=etas1(yn,xn+1)+dx.*(1.0-dy).*METACUR*mwt;
                mus1(yn,xn+1)=mus1(yn,xn+1)+dx.*(1.0-dy).*MMUCUR*mwt;
                sxy1(yn,xn+1)=sxy1(yn,xn+1)+dx.*(1.0-dy).*MSXY(mm1)*mwt;
                wtetas(yn,xn+1)=wtetas(yn,xn+1)+dx.*(1.0-dy)*mwt;
            end
            if(dx>=0.5 && dy>=0.5)
                etas1(yn+1,xn+1)=etas1(yn+1,xn+1)+dx.*dy.*METACUR*mwt;
                mus1(yn+1,xn+1)=mus1(yn+1,xn+1)+dx.*dy.*MMUCUR*mwt;
                sxy1(yn+1,xn+1)=sxy1(yn+1,xn+1)+dx.*dy.*MSXY(mm1)*mwt;
                wtetas(yn+1,xn+1)=wtetas(yn+1,xn+1)+dx.*dy*mwt;
            end

            % Add viscosity etan(), normal stress sxx() and shear modulus mun() to the center of current cell
            etan1(yn,xn)=etan1(yn,xn)+(1.0-abs(0.5-dx)).*(1.0-abs(0.5-dy)).*METACUR*mwt;
            mun1(yn,xn)=mun1(yn,xn)+(1.0-abs(0.5-dx)).*(1.0-abs(0.5-dy)).*MMUCUR*mwt;
            sxx1(yn,xn)=sxx1(yn,xn)+(1.0-abs(0.5-dx)).*(1.0-abs(0.5-dy)).*MSXX(mm1)*mwt;
            wtetan(yn,xn)=wtetan(yn,xn)+(1.0-abs(0.5-dx)).*(1.0-abs(0.5-dy))*mwt;
        end

    end

    % Computing  Viscosity, density, rock type for nodal points
    for i=1:1:ynum;
        for j=1:1:xnum;
            % Density
            if (wtnodes(i,j)~=0)
                % Compute new value interpolated from markers
                rho1(i,j)=rho1(i,j)./wtnodes(i,j);
                tk1(i,j)=tk1(i,j)./wtnodes(i,j);
                kt1(i,j)=kt1(i,j)./wtnodes(i,j);
                rhocp1(i,j)=rhocp1(i,j)./wtnodes(i,j);
                hr1(i,j)=hr1(i,j)./wtnodes(i,j);
                ha1(i,j)=ha1(i,j)./wtnodes(i,j);
            else
                % If no new value is interpolated from markers old value is used
                rho1(i,j)=rho0(i,j);
                tk1(i,j)=tk0(i,j);
                kt1(i,j)=kt0(i,j);
                rhocp1(i,j)=rhocp0(i,j);
                hr1(i,j)=hr0(i,j);
                ha1(i,j)=ha0(i,j);
            end
            % Shear viscosity
            if (wtetas(i,j)~=0)
                % Compute new value interpolated from markers
                etas1(i,j)=etas1(i,j)./wtetas(i,j);
                mus1(i,j)=1/(mus1(i,j)./wtetas(i,j));
                sxy1(i,j)=sxy1(i,j)./wtetas(i,j);
            else
                % If no new value is interpolated from markers old value is used
                etas1(i,j)=etas0(i,j);
                mus1(i,j)=mus0(i,j);
                sxy1(i,j)=sxy0(i,j);
            end
            % Flatten density distribution for "air/water" boundary
            % in order to avoid perturbations in the weak layer
            if (rho1(i,j)<=1000 && gridy(i)<waterlev && hr1(i,j)==0)
                rho1(i,j)=1;
            end
            if (rho1(i,j)<1000 && gridy(i)>=waterlev && hr1(i,j)==0)
                rho1(i,j)=1000;
            end

            % Normal viscosity
            if (i<ynum && j<xnum)
                if (wtetan(i,j)~=0)
                    % Compute new value interpolated from markers
                    etan1(i,j)=etan1(i,j)./wtetan(i,j);
                    mun1(i,j)=1/(mun1(i,j)./wtetan(i,j));
                    sxx1(i,j)=sxx1(i,j)./wtetan(i,j);
                else
                    % If no new value is interpolated from markers old value is used
                    etan1(i,j)=etan0(i,j);
                    mun1(i,j)=mun0(i,j);
                    sxx1(i,j)=sxx0(i,j);
                end
            end
        end
    end

    % Applying thermal boundary conditions for interpolated temperature
    % Upper, Lower boundaries
    for j=2:1:xnum-1
        % Upper boundary
        tk1(1,j)=btopt(j,1)+btopt(j,2)*tk1(2,j);
        % Lower boundary
        tk1(ynum,j)=bbottomt(j,1)+bbottomt(j,2)*tk1(ynum-1,j);
    end
    % Left, Right boundaries: constant temperature
    for i=1:1:ynum
        % Left boundary
        tk1(i,1)=bleftt(i,1)+bleftt(i,2)*tk1(i,2);
        % Right boundary
        tk1(i,xnum)=brightt(i,1)+brightt(i,2)*tk1(i,xnum-1);
    end

    figure(1), clf;
    % Plotting T C
    subplot(3,1,1)
    pcolor(gridx/1000,gridy/1000,tk1-273);
    shading interp;
    axis tight;
    title('T, ^oC')
    colorbar; 
    axis ij image;
    
    % Plotting viscosity
    subplot(3,1,2)
    pcolor(gridx/1000,gridy/1000,log10(etas1));
    shading interp;
    axis tight;
    title('log_{10}(viscosity), Pa s')
    colorbar; 
    axis ij image;
    
    % Plotting density
    subplot(3,1,3)
    pcolor(gridx/1000,gridy/1000,rho1);
    caxis([2500 3400]);
    shading interp;
    axis tight;
    title('density, kg/m^3')
    colorbar; 
    axis ij image;
    pause(1);
    
    
    % Interpolating initial nodal temperatures back to markers
    % to avoid initial discrepancies between markers and nodes 
    if (timesum==0)
        % Marker cycle
        for mm1 = 1:1:marknum

            % Check markers inside the grid
            if (MX(mm1)>=gridx(1) && MX(mm1)<=gridx(xnum) && MY(mm1)>=gridy(1) && MY(mm1)<=gridy(ynum)) 

                %  yn    T(yn,xn)--------------------T(yn,xn+1)
                %           ?           ^                  ?
                %           ?           ?                  ?
                %           ?          dy                  ?
                %           ?           ?                  ?
                %           ?           v                  ?
                %           ?<----dx--->o Mrho(mm1)       ?
                %           ?                              ?
                %           ?                              ?
                %  yn+1  T(yn+1,xn)-------------------V(yn+1,xn+1)
                %
                %
                % Interpolating temperature changes from basic nodes
                %
                % Define indexes for upper left node in the cell where the marker is
                xn=MXN(mm1);
                yn=MYN(mm1);

                % Define normalized distances from marker to the upper left node;
                dx=(MX(mm1)-gridx(xn))./xstp1(xn);
                dy=(MY(mm1)-gridy(yn))./ystp1(yn);

                % Interpolate nodal temperature for the marker
                tkm=0;
                tkm=tkm+(1.0-dx).*(1.0-dy).*tk1(yn,xn);
                tkm=tkm+(1.0-dx).*dy.*tk1(yn+1,xn);
                tkm=tkm+dx.*(1.0-dy).*tk1(yn,xn+1);
                tkm=tkm+dx.*dy.*tk1(yn+1,xn+1);
                % Reset marker temperature
                MTK(mm1)=tkm;

            end
        end
    end    
    
    % Computing viscoelastic (numerical) viscosity and stress
    % Shear stress
    for i=1:1:ynum;
        for j=1:1:xnum;
            %Viscoelasticity factor
            xelvis=etas1(i,j)/(etas1(i,j)+timestep*mus1(i,j));
            % Viscoelastic viscosity = (1-xelvis)*ETA
            etas0(i,j)=etas1(i,j)*(1-xelvis);
            % Vsicoelastic stress = xelvis*Sxy
            sxy0(i,j)=sxy1(i,j)*xelvis;
        end
    end
    % Normal stress
    for i=1:1:ynum-1;
        for j=1:1:xnum-1;
            %Viscoelasticity factor
            xelvis=etan1(i,j)/(etan1(i,j)+timestep*mun1(i,j));
            % Viscoelastic viscosity = (1-xelvis)*ETA
            etan0(i,j)=etan1(i,j)*(1-xelvis);
            % Vsicoelastic stress = xelvis*Sxx
            sxx0(i,j)=sxx1(i,j)*xelvis;
        end
    end

    % Computing right part of mechanical viscoelastic equations
    % x-Stokes
    RX1=zeros(ynum+1,xnum);
    % y-Stokes
    RY1=zeros(ynum,xnum+1);
    % continuity
    RC1=zeros(ynum-1,xnum-1);
    % Grid points cycle
    for i=2:1:ynum;
        for j=2:1:xnum;
            % Right part of x-Stokes Equation
            if(j<xnum)
                RX1(i,j)=-gx*(rho1(i,j)+rho1(i-1,j))/2;
                % Adding xelvis*dSxx0/dx
                RX1(i,j)=RX1(i,j)-(sxx0(i-1,j)-sxx0(i-1,j-1))/xstpc1(j);
                % Adding xelvis*dSxy0/dy
                RX1(i,j)=RX1(i,j)-(sxy0(i,j)-sxy0(i-1,j))/ystp1(i-1);
            end
            % Right part of y-Stokes Equation
            if(i<ynum)
                RY1(i,j)=-gy*(rho1(i,j)+rho1(i,j-1))/2;
                % Adding xelvis*dSyy0/dy using that Syy0=-Sxx0 (deviatoric stress)
                RY1(i,j)=RY1(i,j)+(sxx0(i,j-1)-sxx0(i-1,j-1))/ystpc1(i);
                % Adding xelvis*dSyx0/dx using that Syx0=Sxy0 
                RY1(i,j)=RY1(i,j)-(sxy0(i,j)-sxy0(i,j-1))/xstp1(j-1);
            end
        end
    end


    % Computing velocity field
    if (movemod==0)
        % Solving of Stokes and Continuity equations on nodes
        % and computing residuals
        % by calling function Stokes_Continuity_solver_grid() 
        % with viscoelastic numerical viscosity
        % and modified right parts
        [vx1,resx1,vy1,resy1,pr1,resc1]=Stokes_Continuity_solver_sandbox(prfirst,etas0,etan0,xnum,ynum,gridx,gridy,RX1,RY1,RC1,bleft,bright,btop,bbottom,bintern);
    end
    % Solid body rotation
    if (movemod==1)
        for i=1:1:ynum+1;
            for j=1:1:xnum+1;
                % Vx
                if(j<xnum+1)
                    % Relative distance of vx node from the model center
                    dx=((j-1)*xstp-xsize/2)/(xsize/2);
                    dy=((i-1.5)*ystp-ysize/2)/(xsize/2);
                    dr=(dx^2+dy^2)^0.5;
                    % Set vx
                    vx1(i,j)=-vyright*dy;
                end
                % Vy
                if(i<ynum+1)
                    % Relative distance of vy node from the model center
                    dx=((j-1.5)*xstp-xsize/2)/(xsize/2);
                    dy=((i-1)*ystp-ysize/2)/(xsize/2);
                    dr=(dx^2+dy^2)^0.5;
                    % Set vy
                    vy1(i,j)=vyright*dx;
                end
            end
        end
    end

    % Computing EPS'xx=-EPS'yy, EPSxy=EPSyx deviatoric strain rate tensor components from vx, vy
    % Computing spin tensor Espin
    exy = zeros(ynum,xnum);
    exx = zeros(ynum-1,xnum-1);
    esp = zeros(ynum,xnum);
    eii = zeros(ynum-1,xnum-1);
    % Grid points cycle
    for i=1:1:ynum;
        for j=1:1:xnum;
            % EPS'xx=-EPS'yy=1/2(dvx/dx-dvy/dy)
            if(i<ynum && j<xnum)
                exx(i,j)=0.5*((vx1(i+1,j+1)-vx1(i+1,j))/xstp1(j)-(vy1(i+1,j+1)-vy1(i,j+1))/ystp1(i));
            end
            % EPSxy=EPSyx=1/2(dvx/dy+dvy/dx)
            exy(i,j)=0.5*((vx1(i+1,j)-vx1(i,j))/ystpc1(i)+(vy1(i,j+1)-vy1(i,j))/xstpc1(j));
            % Espin=1/2(dvy/dx-dvx/dy) i.e. positive for clockwise rotation
            % (when x axis is directed rightward and y axis is directed downward) 
            esp(i,j)=0.5*((vy1(i,j+1)-vy1(i,j))/xstpc1(j)-(vx1(i+1,j)-vx1(i,j))/ystpc1(i));
            % EPSii=(EPS'xx^2+EPSxy^2)^0.5
            if(i>1 && j>1)
                eii(i-1,j-1)=(exx(i-1,j-1)^2+(exy(i-1,j-1)^2+exy(i,j-1)^2+exy(i-1,j)^2+exy(i,j)^2)/4)^0.5;
            end
        end
    end

    % Check maximal velocity
    vxmax=max(abs(max(max(vx1))),abs(min(min(vx1))));
    vymax=max(abs(max(max(vy1))),abs(min(min(vy1))));
    % Check marker displacement step
    if (vxmax>0)
        if (timestep>markmax*xstp/vxmax);
            timestep=markmax*xstp/vxmax;
        end
    end
    if (vymax>0)
        if (timestep>markmax*ystp/vymax);
            timestep=markmax*ystp/vymax;
        end
    end
    % Defining displacement timestep
    timestep=timestep % final displacement step
    timestepd=timestep;
    
    % Computing new stresses and stress change using the displacement timestep
    sxy2 = zeros(ynum,xnum);
    sxx2 = zeros(ynum-1,xnum-1);
    % Shear stress
    for i=1:1:ynum;
        for j=1:1:xnum;
            %Viscoelasticity factor
            xelvis=etas1(i,j)/(etas1(i,j)+timestep*mus1(i,j));
            % New viscoelastic stress = (1-xelvis)*2*ETA*EPSxy + xelvis*Sxy0
            sxy2(i,j)=(1-xelvis)*2*etas1(i,j)*exy(i,j)+xelvis*sxy1(i,j);
        end
    end
    % Normal stress
    for i=1:1:ynum-1;
        for j=1:1:xnum-1;
            %Viscoelasticity factor
            xelvis=etan1(i,j)/(etan1(i,j)+timestep*mun1(i,j));
            % New viscoelastic stress = (1-xelvis)*2*ETA*EPSxx + xelvis*Sxx0
            sxx2(i,j)=(1-xelvis)*2*etan1(i,j)*exx(i,j)+xelvis*sxx1(i,j);
        end
    end
    % Stress change
    dsxy = sxy2-sxy1;
    dsxx = sxx2-sxx1;
    
    % Computing strain rate and pressure for markers
    for mm1 = 1:1:marknum
        
        % Check markers inside the grid
        if (MX(mm1)>=gridx(1) && MX(mm1)<=gridx(xnum) && MY(mm1)>=gridy(1) && MY(mm1)<=gridy(ynum)) 

            %  xn    V(xn,yn)--------------------V(xn+1,yn)
            %           ?           ^                  ?
            %           ?           ?                  ?
            %           ?          dy                  ?
            %           ?           ?                  ?
            %           ?           v                  ?
            %           ?<----dx--->o Mrho(xm,ym)       ?
            %           ?                              ?
            %           ?                              ?
            %  xn+1  V(xn,yn+1)-------------------V(xn+1,yn+1)

            % Define indexes for upper left BASIC node in the cell where the marker is
            xnmin=MXN(mm1);
            ynmin=MYN(mm1);

            % Calculating strain rate for marker
            %
            % Interpolating squares of EPS'xx=-EPS'yy from cell centers
            % EPS'xx-nodes are displaced rightward and downward for 1/2 of gridsteps
            % Horizontal EPS'xx index
            xn=xnmin;
            if(MX(mm1)<gridcx(xn+1))
                xn=xn-1;
            end
            if (xn<1)
                xn=1;
            end
            if (xn>xnum-2)
                xn=xnum-2;
            end
            % Vertical EPS'xx index
            yn=ynmin;
            if(MY(mm1)<gridcy(yn+1))
                yn=yn-1;
            end
            if (yn<1)
                yn=1;
            end
            if (yn>ynum-2)
                yn=ynum-2;
            end

            % Define and check normalized distances from marker to the upper left EPS'xx-node;
            dx=(MX(mm1)-gridcx(xn+1))./xstpc1(xn+1);
            dy=(MY(mm1)-gridcy(yn+1))./ystpc1(yn+1);

            % Calculate and save Marker EPS'xx from four surrounding nodes
            exxm=0;
            exxm=exxm+(1.0-dx).*(1.0-dy).*exx(yn,xn);
            exxm=exxm+(1.0-dx).*dy.*exx(yn+1,xn);
            exxm=exxm+dx.*(1.0-dy).*exx(yn,xn+1);
            exxm=exxm+dx.*dy.*exx(yn+1,xn+1);
            MEXX(mm1)=exxm;
            % Calculate Marker SIG'xx from four surrounding nodes
            sxxm=0;
            sxxm=sxxm+(1.0-dx).*(1.0-dy).*sxx2(yn,xn);
            sxxm=sxxm+(1.0-dx).*dy.*sxx2(yn+1,xn);
            sxxm=sxxm+dx.*(1.0-dy).*sxx2(yn,xn+1);
            sxxm=sxxm+dx.*dy.*sxx2(yn+1,xn+1);
            % Calculate Marker dSIG'xx from four surrounding nodes
            dsxxm=0;
            dsxxm=dsxxm+(1.0-dx).*(1.0-dy).*dsxx(yn,xn);
            dsxxm=dsxxm+(1.0-dx).*dy.*dsxx(yn+1,xn);
            dsxxm=dsxxm+dx.*(1.0-dy).*dsxx(yn,xn+1);
            dsxxm=dsxxm+dx.*dy.*dsxx(yn+1,xn+1);


            % Calculate and save Marker pressure from four surrounding nodes
            prm=0;
            prm=prm+(1.0-dx).*(1.0-dy).*pr1(yn,xn);
            prm=prm+(1.0-dx).*dy.*pr1(yn+1,xn);
            prm=prm+dx.*(1.0-dy).*pr1(yn,xn+1);
            prm=prm+dx.*dy.*pr1(yn+1,xn+1);
            MPR(mm1)=prm;


            % Interpolating EPSxy=EPSyx from basic nodes
            % Horizontal EPSxy index
            xn=xnmin;
            % Vertical EPSxy index
            yn=ynmin;

            % Define and check normalized distances from marker to the upper left VX-node;
            dx=(MX(mm1)-gridx(xn))./xstp1(xn);
            dy=(MY(mm1)-gridy(yn))./ystp1(yn);

            % Calculate and save Marker EPSxy from four surrounding nodes
            exym=0;
            exym=exym+(1.0-dx).*(1.0-dy).*exy(yn,xn);
            exym=exym+(1.0-dx).*dy.*exy(yn+1,xn);
            exym=exym+dx.*(1.0-dy).*exy(yn,xn+1);
            exym=exym+dx.*dy.*exy(yn+1,xn+1);
            MEXY(mm1)=exym;
            % Calculate Marker SIGxy from four surrounding nodes
            sxym=0;
            sxym=sxym+(1.0-dx).*(1.0-dy).*sxy2(yn,xn);
            sxym=sxym+(1.0-dx).*dy.*sxy2(yn+1,xn);
            sxym=sxym+dx.*(1.0-dy).*sxy2(yn,xn+1);
            sxym=sxym+dx.*dy.*sxy2(yn+1,xn+1);
            % Calculate Marker SIGxy from four surrounding nodes
            dsxym=0;
            dsxym=dsxym+(1.0-dx).*(1.0-dy).*dsxy(yn,xn);
            dsxym=dsxym+(1.0-dx).*dy.*dsxy(yn+1,xn);
            dsxym=dsxym+dx.*(1.0-dy).*dsxy(yn,xn+1);
            dsxym=dsxym+dx.*dy.*dsxy(yn+1,xn+1);

            % Computing second strain rate invariant 
            % for the marker using grid values
            eiimg=(MEXX(mm1)^2+MEXY(mm1)^2)^0.5;
            % Correcting strain rate for the marker using Maxwell model  
            if (eiimg>0)
                % Computing second strain rate invariant for the marker
                % from stresses using Maxwell model
                eiim=((sxxm/2/META(mm1)+dsxxm/2/timestep/MMU(MI(mm1)))^2+(sxym/2/META(mm1)+dsxym/2/timestep/MMU(MI(mm1)))^2)^0.5;
                % Computing EiiMarker/EiiGrid ratio
                MRAT(mm1)=(eiim/eiimg);
            else
                MRAT(mm1)=1;
            end
        end
    end


    % Computing subgrid stress changes for markers
    if (dsubgrids>0)
        % Clear subgrid stress changes for nodes
        dsxyn=zeros(ynum,xnum);
        dsxxn=zeros(ynum-1,xnum-1);
        % Clear wights for Sxy
        wtetas=zeros(ynum,xnum);
        % Clear wights for Sxx
        wtetan=zeros(ynum-1,xnum-1);
        % Marker cycle
        for mm1 = 1:1:marknum
 
        % Check markers inside the grid
            if (MX(mm1)>=gridx(1) && MX(mm1)<=gridx(xnum) && MY(mm1)>=gridy(1) && MY(mm1)<=gridy(ynum)) 

                % Compute local stress relaxation timescale (Maxwell time) for the marker
                sdm=META(mm1)/MMU(MI(mm1));
                % Computing degree of subgrid stress relaxation
                sdif=-dsubgrids*timestep/sdm;
                if(sdif<-30) 
                    sdif=-30;
                end
                sdif=(1-exp(sdif));

                %  yn    sxy(yn,xn)--------------------sxy(yn,xn+1)
                %           ?           ^                  ?
                %           ?           ?                  ?
                %           ?          dy                  ?
                %           ?           ?                  ?
                %           ?           v                  ?
                %           ?<----dx--->o MSXY(mm1)      ?
                %           ?                              ?
                %           ?                              ?
                %  yn+1  sxy(yn+1,xn)-------------------sxy(yn+1,xn+1)
                %
                %
                % Interpolating old shear stress from Sxy nodes
                %
                % Define indexes for upper left node in the cell where the marker is
                xn=MXN(mm1);
                yn=MYN(mm1);

                % Define normalized distances from marker to the upper left node;
                dx=(MX(mm1)-gridx(xn))./xstp1(xn);
                dy=(MY(mm1)-gridy(yn))./ystp1(yn);

                % Compute marker weight koefficient from cell dimensions
                % Number of markers in a cell is in invert proportion to the cell volume
                mwt=1;%/xstp1(xn)/ystp1(yn);


                % Interpolate old Sxy stress for the marker
                sxym=0;
                sxym=sxym+(1.0-dx).*(1.0-dy).*sxy1(yn,xn);
                sxym=sxym+(1.0-dx).*dy.*sxy1(yn+1,xn);
                sxym=sxym+dx.*(1.0-dy).*sxy1(yn,xn+1);
                sxym=sxym+dx.*dy.*sxy1(yn+1,xn+1);
                % Calculate Nodal-Marker subgrid Sxy stress difference
                dsxym=sxym-MSXY(mm1);
                % Relaxing Nodal-Marker subgrid Sxy stress difference
                dsxym=dsxym*sdif;    

                % Correcting old stress for the marker
                MSXY(mm1)=MSXY(mm1)+dsxym;

                % Interpolating subgrid Sxy stress changes to 4 nodes
                % only using markers located at <=0.5 gridstep distances from nodes
                if(dx<=0.5 && dy<=0.5)
                    dsxyn(yn,xn)=dsxyn(yn,xn)+(1.0-dx).*(1.0-dy).*dsxym*mwt;
                    wtetas(yn,xn)=wtetas(yn,xn)+(1.0-dx).*(1.0-dy)*mwt;
                end
                if(dx<=0.5 && dy>=0.5)
                    dsxyn(yn+1,xn)=dsxyn(yn+1,xn)+(1.0-dx).*dy.*dsxym*mwt;
                    wtetas(yn+1,xn)=wtetas(yn+1,xn)+(1.0-dx).*dy*mwt;
                end
                if(dx>=0.5 && dy<=0.5)
                    dsxyn(yn,xn+1)=dsxyn(yn,xn+1)+dx.*(1.0-dy).*dsxym*mwt;
                    wtetas(yn,xn+1)=wtetas(yn,xn+1)+dx.*(1.0-dy)*mwt;
                end
                if(dx>=0.5 && dy>=0.5)
                    dsxyn(yn+1,xn+1)=dsxyn(yn+1,xn+1)+dx.*dy.*dsxym*mwt;
                    wtetas(yn+1,xn+1)=wtetas(yn+1,xn+1)+dx.*dy*mwt;
                end

                % Computing marker weight for the center of current
                % basic cell where Sxx stress is located
                mwt=mwt*(1.0-abs(0.5-dx)).*(1.0-abs(0.5-dy));
                %  yn    sxx(yn,xn)--------------------sxx(yn,xn+1)
                %           ?           ^                  ?
                %           ?           ?                  ?
                %           ?          dy                  ?
                %           ?           ?                  ?
                %           ?           v                  ?
                %           ?<----dx--->o MSXX(mm1)       ?
                %           ?                              ?
                %           ?                              ?
                %  yn+1  sxx(yn+1,xn)-------------------sxx(yn+1,xn+1)
                %
                %
                % Interpolating old normal stress from Sxx nodes
                %
                % Define, check indexes for upper left node in the Sxx cell where the marker is
                if (MX(mm1)<gridcx(xn+1))
                    xn=xn-1;
                end
                if(xn<1)
                    xn=1;
                end
                if(xn>xnum-2)
                    xn=xnum-2;
                end
                if (MY(mm1)<gridcy(yn+1))
                    yn=yn-1;
                end
                if(yn<1)
                    yn=1;
                end
                if(yn>ynum-2)
                    yn=ynum-2;
                end

                % Define normalized distances from marker to the upper left node;
                dx=(MX(mm1)-gridcx(xn+1))./xstpc1(xn+1);
                dy=(MY(mm1)-gridcy(yn+1))./ystpc1(yn+1);

                % Interpolate old Sxx stress for the marker
                sxxm=0;
                sxxm=sxxm+(1.0-dx).*(1.0-dy).*sxx1(yn,xn);
                sxxm=sxxm+(1.0-dx).*dy.*sxx1(yn+1,xn);
                sxxm=sxxm+dx.*(1.0-dy).*sxx1(yn,xn+1);
                sxxm=sxxm+dx.*dy.*sxx1(yn+1,xn+1);
                % Calculate Nodal-Marker subgrid Sxx stress difference
                dsxxm=sxxm-MSXX(mm1);
                % Relaxing Nodal-Marker subgrid Sxx stress difference
                dsxxm=dsxxm*sdif;    

                % Correcting old stress for the marker
                MSXX(mm1)=MSXX(mm1)+dsxxm;

                % Interpolating subgrid Sxx stress changes for the center of current basic cell
                xn=MXN(mm1);
                yn=MYN(mm1);
                dsxxn(yn,xn)=dsxxn(yn,xn)+dsxxm*mwt;
                wtetan(yn,xn)=wtetan(yn,xn)+mwt;

            end
        end
 
        % Computing subgrid stress changes for nodes
        for i=1:1:ynum;
            for j=1:1:xnum;
                % Density
                if (wtetas(i,j)~=0)
                    % Compute new value interpolated from markers
                    dsxyn(i,j)=dsxyn(i,j)./wtetas(i,j);
                end
                if (j<xnum && i<ynum && wtetan(i,j)~=0)
                    % Compute new value interpolated from markers
                    dsxxn(i,j)=dsxxn(i,j)./wtetan(i,j);
                end
            end
        end

        % Subtracting subgrid stress change part from nodal stress changes
        dsxy=dsxy-dsxyn;
        dsxx=dsxx-dsxxn;

    end

    % Updating stress for markers
    for mm1 = 1:1:marknum

        % Check markers inside the grid
        if (MX(mm1)>=gridx(1) && MX(mm1)<=gridx(xnum) && MY(mm1)>=gridy(1) && MY(mm1)<=gridy(ynum)) 

            %  yn    sxy(yn,xn)--------------------sxy(yn,xn+1)
            %           ?           ^                  ?
            %           ?           ?                  ?
            %           ?          dy                  ?
            %           ?           ?                  ?
            %           ?           v                  ?
            %           ?<----dx--->o MSXY(mm1)       ?
            %           ?                              ?
            %           ?                              ?
            %  yn+1  sxy(yn+1,xn)-------------------sxy(yn+1,xn+1)
            %
            %
            % Interpolating old shear stress changes from Sxy nodes
            %
            % Define indexes for upper left node in the cell where the marker is
            xn=MXN(mm1);
            yn=MYN(mm1);

            % Define normalized distances from marker to the upper left node;
            dx=(MX(mm1)-gridx(xn))./xstp1(xn);
            dy=(MY(mm1)-gridy(yn))./ystp1(yn);

            % Interpolate old Sxy stress change for the marker
            dsxym=0;
            dsxym=dsxym+(1.0-dx).*(1.0-dy).*dsxy(yn,xn);
            dsxym=dsxym+(1.0-dx).*dy.*dsxy(yn+1,xn);
            dsxym=dsxym+dx.*(1.0-dy).*dsxy(yn,xn+1);
            dsxym=dsxym+dx.*dy.*dsxy(yn+1,xn+1);

            % Update stress for the marker
            MSXY(mm1)=MSXY(mm1)+dsxym;

            %  yn    sxx(yn,xn)--------------------sxx(yn,xn+1)
            %           ?           ^                  ?
            %           ?           ?                  ?
            %           ?          dy                  ?
            %           ?           ?                  ?
            %           ?           v                  ?
            %           ?<----dx--->o MSXX(mm1)       ?
            %           ?                              ?
            %           ?                              ?
            %  yn+1  sxx(yn+1,xn)-------------------sxx(yn+1,xn+1)
            %
            %
            % Interpolating old normal stress changes from Sxx nodes
            %
            % Define, check indexes for upper left node in the Sxx cell where the marker is
            if (MX(mm1)<gridcx(xn+1))
                xn=xn-1;
            end
            if(xn<1)
                xn=1;
            end
            if(xn>xnum-2)
                xn=xnum-2;
            end
            if (MY(mm1)<gridcy(yn+1))
                yn=yn-1;
            end
            if(yn<1)
                yn=1;
            end
            if(yn>ynum-2)
                yn=ynum-2;
            end

            % Define normalized distances from marker to the upper left node;
            dx=(MX(mm1)-gridcx(xn+1))./xstpc1(xn+1);
            dy=(MY(mm1)-gridcy(yn+1))./ystpc1(yn+1);

            % Interpolate old Sxx stress for the marker
            dsxxm=0;
            dsxxm=dsxxm+(1.0-dx).*(1.0-dy).*dsxx(yn,xn);
            dsxxm=dsxxm+(1.0-dx).*dy.*dsxx(yn+1,xn);
            dsxxm=dsxxm+dx.*(1.0-dy).*dsxx(yn,xn+1);
            dsxxm=dsxxm+dx.*dy.*dsxx(yn+1,xn+1);

            % Correcting old stress for the marker
            MSXX(mm1)=MSXX(mm1)+dsxxm;

        end
    end


    
    % Solving Temperature equation
    if (timestep>0 && tempmax>0)
        
        % Computing right part of temperature equation
        RT1=hr1;
        % Grid points cycle
        for i=2:1:ynum-1;
            for j=2:1:xnum-1;
                % Adiabatic heating on(1)/off(0)
                if(adiabyn==1)
                    % Adding alp*T*DP/dt where DP/dt ~ vx*gx*rho+vy*gy*rho
                    RT1(i,j)=RT1(i,j)+ha1(i,j)*rho1(i,j)*(gx*(vx1(i,j)+vx1(i+1,j))+gy*(vy1(i,j)+vy1(i,j+1)))/2;
                end
                % Computing viscoelastic shear heating for Temperature nodes
                % Hs=2*Sxx*Sxx/2/etan+2*Sxy*Sxy/2/etas
                % Shear heating on(1)/off(0)
                if(frictyn==1)
                    % Adding 2*Sxy*Sxy/2/etas
                    RT1(i,j)=RT1(i,j)+sxy2(i,j)^2/etas1(i,j);
                    % Computing and adding 2*Sxx*Sxx/2/etan
                    RT1(i,j)=RT1(i,j)+(sxx2(i-1,j-1)^2/etan1(i-1,j-1)+sxx2(i,j-1)^2/etan1(i,j-1)+sxx2(i-1,j)^2/etan1(i-1,j)+sxx2(i,j)^2/etan1(i,j))/4;
                end
            end
        end

        % Solving temperature equation making (if needed) several thermal
        % timesteps for one displacement timestep
        % Set current thermal timestep 
        timestept=timestep
        % Set total thermal timestep
        timesteps=0;
        % Set old Temperature
        tk0=tk1;
        while (timesteps<timestep)
            % Solving Temperature equation with thermal timestep
            [tk2,rest]=Temperature_solver_grid(timestept,xnum,ynum,gridx,gridy,kt1,rhocp1,tk0,RT1,bleftt,brightt,btopt,bbottomt);
            % Computing temperature changes
            dtk1=tk2-tk0;
            % Checking temperature changes
            dtkmax=max(max(abs(dtk1)))
            % Repeating temperature solution if temperature changes are too big
            if(dtkmax>tempmax)
                % Computing reduced timestep
                timestept=timestept*tempmax/dtkmax
                % Solving Temperature equation with reduced timestep
                [tk2,rest]=Temperature_solver_grid(timestept,xnum,ynum,gridx,gridy,kt1,rhocp1,tk0,RT1,bleftt,brightt,btopt,bbottomt);
                % Computing temperature changes
            end
            % Add total thermal timestep
            timesteps=timesteps+timestept
            % Compute current thermal timestep
            if (timestept>timestep-timesteps)
                timestept=timestep-timesteps
            else
                timestept=timestept
            end
            % Update old temperature
            tk0=tk2;
        end
        % Compute temperature changes
        dtk1=tk2-tk1;


        % Computing subgrid diffusion for markers
        if (dsubgridt>0)
            % Clear subgrid temperature changes for nodes
            dtkn=zeros(ynum,xnum);
            % Clear wights for basic nodes
            wtnodes=zeros(ynum,xnum);
            % Marker cycle
            for mm1 = 1:1:marknum
                    
                % Check markers inside the grid
                if (MX(mm1)>=gridx(1) && MX(mm1)<=gridx(xnum) && MY(mm1)>=gridy(1) && MY(mm1)<=gridy(ynum)) 

                    %  yn    T(yn,xn)--------------------T(yn,xn+1)
                    %           ?           ^                  ?
                    %           ?           ?                  ?
                    %           ?          dy                  ?
                    %           ?           ?                  ?
                    %           ?           v                  ?
                    %           ?<----dx--->o Mrho(mm1)       ?
                    %           ?                              ?
                    %           ?                              ?
                    %  yn+1  T(yn+1,xn)-------------------V(yn+1,xn+1)
                    %
                    %
                    % Interpolating temperature changes from basic nodes
                    %
                    % Define indexes for upper left node in the cell where the marker is
                    xn=MXN(mm1);
                    yn=MYN(mm1);

                    % Define normalized distances from marker to the upper left node;
                    dx=(MX(mm1)-gridx(xn))./xstp1(xn);
                    dy=(MY(mm1)-gridy(yn))./ystp1(yn);

                    % Compute marker weight koefficient from cell dimensions
                    % Number of markers in a cell is in invert proportion to the cell volume
                    mwt=1;%/xstp1(xn)/ystp1(yn);


                    % Interpolate old nodal temperature for the marker
                    tkm=0;
                    tkm=tkm+(1.0-dx).*(1.0-dy).*tk1(yn,xn);
                    tkm=tkm+(1.0-dx).*dy.*tk1(yn+1,xn);
                    tkm=tkm+dx.*(1.0-dy).*tk1(yn,xn+1);
                    tkm=tkm+dx.*dy.*tk1(yn+1,xn+1);
                    % Calculate Nodal-Marker subgrid temperature difference
                    dtkm=tkm-MTK(mm1);
                    % Compute nodal k and RHO*Cp for the marker 
                    % k
                    ktm=0;
                    ktm=ktm+(1.0-dx).*(1.0-dy).*kt1(yn,xn);
                    ktm=ktm+(1.0-dx).*dy.*kt1(yn+1,xn);
                    ktm=ktm+dx.*(1.0-dy).*kt1(yn,xn+1);
                    ktm=ktm+dx.*dy.*kt1(yn+1,xn+1);
                    % RHO*Cp
                    rhocpm=0;
                    rhocpm=rhocpm+(1.0-dx).*(1.0-dy).*rhocp1(yn,xn);
                    rhocpm=rhocpm+(1.0-dx).*dy.*rhocp1(yn+1,xn);
                    rhocpm=rhocpm+dx.*(1.0-dy).*rhocp1(yn,xn+1);
                    rhocpm=rhocpm+dx.*dy.*rhocp1(yn+1,xn+1);

                    % Compute local thermal diffusion timescale for the marker
                    tdm=rhocpm/ktm/(2/xstp^2+2/ystp^2);

                    % Computing subgrid diffusion
                    sdif=-dsubgridt*timestep/tdm;
                    if(sdif<-30) 
                        sdif=-30;
                    end
                    dtkm=dtkm*(1-exp(sdif));    

                    % Correcting old temperature for the marker
                    MTK(mm1)=MTK(mm1)+dtkm;

                    % Interpolating subgrid temperature changes to 4 nodes
                    dtkn(yn,xn)=dtkn(yn,xn)+(1.0-dx).*(1.0-dy).*dtkm*mwt;
                    wtnodes(yn,xn)=wtnodes(yn,xn)+(1.0-dx).*(1.0-dy)*mwt;

                    dtkn(yn+1,xn)=dtkn(yn+1,xn)+(1.0-dx).*dy.*dtkm*mwt;
                    wtnodes(yn+1,xn)=wtnodes(yn+1,xn)+(1.0-dx).*dy*mwt;

                    dtkn(yn,xn+1)=dtkn(yn,xn+1)+dx.*(1.0-dy).*dtkm*mwt;
                    wtnodes(yn,xn+1)=wtnodes(yn,xn+1)+dx.*(1.0-dy)*mwt;

                    dtkn(yn+1,xn+1)=dtkn(yn+1,xn+1)+dx.*dy.*dtkm*mwt;
                    wtnodes(yn+1,xn+1)=wtnodes(yn+1,xn+1)+dx.*dy*mwt;

                end
            end

            % Computing subgrid diffusion for nodes
            for i=1:1:ynum;
                for j=1:1:xnum;
                    % Density
                    if (wtnodes(i,j)~=0)
                        % Compute new value interpolated from markers
                        dtkn(i,j)=dtkn(i,j)./wtnodes(i,j);
                    end
                end
            end
            
            % Subtracting subgrid diffusion part from nodal temperature changes
            dtk1=dtk1-dtkn;
            
        end
        
        % Updating temperature for markers
        for mm1 = 1:1:marknum

            % Check markers inside the grid
            if (MX(mm1)>=gridx(1) && MX(mm1)<=gridx(xnum) && MY(mm1)>=gridy(1) && MY(mm1)<=gridy(ynum)) 

                %  yn    T(yn,xn)--------------------T(yn,xn+1)
                %           ?           ^                  ?
                %           ?           ?                  ?
                %           ?          dy                  ?
                %           ?           ?                  ?
                %           ?           v                  ?
                %           ?<----dx--->o Mrho(mm1)       ?
                %           ?                              ?
                %           ?                              ?
                %  yn+1  T(yn+1,xn)-------------------V(yn+1,xn+1)
                %
                %
                % Interpolating temperature changes from basic nodes
                %
                % Define indexes for upper left node in the cell where the marker is
                xn=MXN(mm1);
                yn=MYN(mm1);

                % Define normalized distances from marker to the upper left node;
                dx=(MX(mm1)-gridx(xn))./xstp1(xn);
                dy=(MY(mm1)-gridy(yn))./ystp1(yn);

                % Calculate Marker temperature change from four surrounding nodes
                dtkm=0;
                dtkm=dtkm+(1.0-dx).*(1.0-dy).*dtk1(yn,xn);
                dtkm=dtkm+(1.0-dx).*dy.*dtk1(yn+1,xn);
                dtkm=dtkm+dx.*(1.0-dy).*dtk1(yn,xn+1);
                dtkm=dtkm+dx.*dy.*dtk1(yn+1,xn+1);
                %
                %Computing new temperature for the marker
                MTK(mm1)=MTK(mm1)+dtkm;

            end
        end

    end

    % Moving Markers by velocity field
    if(markmove>0)
        % Create arrays for velocity and spin of markers
        vxm=zeros(4,1);
        vym=zeros(4,1);
        espm=zeros(4,1);
        % Marker cycle
        for mm1 = 1:1:marknum

            % Check markers inside the grid
            if (MX(mm1)>=gridx(1) && MX(mm1)<=gridx(xnum) && MY(mm1)>=gridy(1) && MY(mm1)<=gridy(ynum)) 

                % Save marker coordinates
                xcur=MX(mm1);
                ycur=MY(mm1);
                % Defining number of Runge-Kutta cycles
                for rk=1:1:markmove

                    %  xn    V(xn,yn)--------------------V(xn+1,yn)
                    %           ?           ^                  ?
                    %           ?           ?                  ?
                    %           ?          dy                  ?
                    %           ?           ?                  ?
                    %           ?           v                  ?
                    %           ?<----dx--->o Mrho(xm,ym)       ?
                    %           ?                              ?
                    %           ?                              ?
                    %  xn+1  V(xn,yn+1)-------------------V(xn+1,yn+1)

                    % Define indexes for upper left BASIC node in the cell where the marker is
                    % using bisection
                    % Load horizontal and vertical indexes
                    if(rk==1)
                        xnmin=MXN(mm1);
                        ynmin=MYN(mm1);
                    else
                        % Find horizontal index
                        xnmin=1;
                        xnmax=xnum;
                        while ((xnmax-xnmin)>1)
                            % !!! SUBTRACT 0.5 since int16(0.5)=1
                            xn=double(int16((xnmax+xnmin)./2-0.5));
                            if(gridx(xn)>xcur)
                                xnmax=xn;
                            else
                                xnmin=xn;
                            end
                        end
                        % Check horizontal index
                        if (xnmin<1)
                            xnmin=1;
                        end
                        if (xnmin>xnum-1)
                            xnmin=xnum-1;
                        end
                        % Find vertical index
                        ynmin=1;
                        ynmax=ynum;
                        while ((ynmax-ynmin)>1)
                            % !!! SUBTRACT 0.5 since int16(0.5)=1
                            yn=double(int16((ynmax+ynmin)./2-0.5));
                            if(gridy(yn)>ycur)
                                ynmax=yn;
                            else
                                ynmin=yn;
                            end
                        end
                        % Check vertical index
                        if (ynmin<1)
                            ynmin=1;
                        end
                        if (ynmin>ynum-1)
                            ynmin=ynum-1;
                        end
                    end

                    % Define indexes for upper left node in the Vx-cell where the marker is
                    % Horizontal Vx index
                    xn=xnmin;
                    % Vertical Vx index
                    yn=ynmin;
                    if(ycur>gridcy(yn+1))
                        yn=yn+1;
                    end
                    if (yn>ynum)
                        yn=ynum;
                    end

                    % Define and check normalized distances from marker to the upper left VX-node;
                    dx=(xcur-gridx(xn))./xstp1(xn);
                    dy=(ycur-gridcy(yn))./ystpc1(yn);

                    % Calculate Marker velocity from four surrounding Vx nodes
                    vxm(rk)=0;
                    vxm(rk)=vxm(rk)+(1.0-dx).*(1.0-dy).*vx1(yn,xn);
                    vxm(rk)=vxm(rk)+(1.0-dx).*dy.*vx1(yn+1,xn);
                    vxm(rk)=vxm(rk)+dx.*(1.0-dy).*vx1(yn,xn+1);
                    vxm(rk)=vxm(rk)+dx.*dy.*vx1(yn+1,xn+1);

                    % Define indexes for upper left node in the VY-cell where the marker is
                    % Vertical Vy index
                    yn=ynmin;
                    % Horizontal Vy index
                    xn=xnmin;
                    if(xcur>gridcx(xn+1))
                        xn=xn+1;
                    end
                    if (xn>xnum)
                        xn=xnum;
                    end

                    % Define and check normalized distances from marker to the upper left VX-node;
                    dx=(xcur-gridcx(xn))./xstpc1(xn);
                    dy=(ycur-gridy(yn))./ystp1(yn);

                    % Calculate Marker velocity from four surrounding nodes
                    vym(rk)=0;
                    vym(rk)=vym(rk)+(1.0-dx).*(1.0-dy).*vy1(yn,xn);
                    vym(rk)=vym(rk)+(1.0-dx).*dy.*vy1(yn+1,xn);
                    vym(rk)=vym(rk)+dx.*(1.0-dy).*vy1(yn,xn+1);
                    vym(rk)=vym(rk)+dx.*dy.*vy1(yn+1,xn+1);

                    % Define indexes for upper left node in the Espin cell where the marker is
                    xn=xnmin;
                    yn=ynmin;

                    % Define normalized distances from marker to the upper left node;
                    dx=(xcur-gridx(xn))./xstp1(xn);
                    dy=(ycur-gridy(yn))./ystp1(yn);

                    % Interpolate old Sxy stress for the marker
                    espm(rk)=0;
                    espm(rk)=espm(rk)+(1.0-dx).*(1.0-dy).*esp(yn,xn);
                    espm(rk)=espm(rk)+(1.0-dx).*dy.*esp(yn+1,xn);
                    espm(rk)=espm(rk)+dx.*(1.0-dy).*esp(yn,xn+1);
                    espm(rk)=espm(rk)+dx.*dy.*esp(yn+1,xn+1);


                    % Update coordinates for the next cycle
                    if(rk<4)
                        if (rk<3)
                            xcur=MX(mm1)+timestep/2*vxm(rk);
                            ycur=MY(mm1)+timestep/2*vym(rk);
                        else
                            xcur=MX(mm1)+timestep*vxm(rk);
                            ycur=MY(mm1)+timestep*vym(rk);
                        end
                    end


                end
                % Recompute velocity and spin using 4-th order Runge_Kutta
                if (markmove==4)
                    vxm(1)=(vxm(1)+2*vxm(2)+2*vxm(3)+vxm(4))/6;
                    vym(1)=(vym(1)+2*vym(2)+2*vym(3)+vym(4))/6;
                    espm(1)=(espm(1)+2*espm(2)+2*espm(3)+espm(4))/6;
                end

                % Displacing Marker according to its velocity
                MX(mm1)=MX(mm1)+timestep*vxm(1);
                MY(mm1)=MY(mm1)+timestep*vym(1);
                
                % Rotate stress on marker according to its spin
                % Compute amount of rotation from spin rate:
                % Espin=1/2(dvy/dx-dvx/dy) i.e. positive for clockwise rotation
                % (when x axis is directed rightward and y axis is directed downward) 
                espm(1)=espm(1)*timestep;
                % Save old stresses
                msxxold=MSXX(mm1);
                msxyold=MSXY(mm1);
                % SxyNEW=0.5(Sxx-Syy)*sin(2*Espin*dt)+Sxy*cos(2*Espin*dt)
                % where Sxx-Syy=2Sxx
                MSXY(mm1)=msxxold*sin(2*espm(1))+msxyold*cos(2*espm(1));
                % SxxNEW=Sxx*(cos(Espin*dt))^2+Syy*(sin(Espin*dt))^2-Sxy*sin(2*Espin*dt)
                % where Sxx=-Syy
                MSXX(mm1)=msxxold*((cos(espm(1)))^2-(sin(espm(1)))^2)-msxyold*sin(2*espm(1));

                % Adding marker plastic strain based on grid strain rates
                if (MGII(mm1)>0)
                    MGII(mm1)=MGII(mm1)+timestep*(MEXX(mm1)^2+MEXY(mm1)^2)^0.5;
                end
                % Adding marker bulk strain based on grid strain rates
                MBII(mm1)=MBII(mm1)+timestep*(MEXX(mm1)^2+MEXY(mm1)^2)^0.5;

            end

        end
    end
    
    % Recomputing topography surface
    % Set velocity initially to zero
    gridt(4:1:6,:)=0;
    % Defining advection velocity at topography points
    for i=1:1:tnum
        % Check topography nodes inside the grid
        if (gridt(1,i)>=gridx(1) && gridt(1,i)<=gridx(xnum) && gridt(2,i)>=gridy(1) && gridt(2,i)<=gridy(ynum)) 
            %  xn    V(xn,yn)--------------------V(xn+1,yn)
            %           ?           ^                  ?
            %           ?           ?                  ?
            %           ?          dy                  ?
            %           ?           ?                  ?
            %           ?           v                  ?
            %           ?<----dx--->o Mrho(xm,ym)       ?
            %           ?                              ?
            %           ?                              ?
            %  xn+1  V(xn,yn+1)-------------------V(xn+1,yn+1)

            % Define indexes for upper left BASIC node in the cell where the topograhy node is
            % using bisection
            xcur=gridt(1,i);
            ycur=gridt(2,i);
            % Find horizontal index
            xnmin=1;
            xnmax=xnum;
            while ((xnmax-xnmin)>1)
                % !!! SUBTRACT 0.5 since int16(0.5)=1
                xn=double(int16((xnmax+xnmin)./2-0.5));
                if(gridx(xn)>xcur)
                    xnmax=xn;
                else
                    xnmin=xn;
                end
            end
            % Check horizontal index
            if (xnmin<1)
                xnmin=1;
            end
            if (xnmin>xnum-1)
                xnmin=xnum-1;
            end
            % Find vertical index
            ynmin=1;
            ynmax=ynum;
            while ((ynmax-ynmin)>1)
                % !!! SUBTRACT 0.5 since int16(0.5)=1
                yn=double(int16((ynmax+ynmin)./2-0.5));
                if(gridy(yn)>ycur)
                    ynmax=yn;
                else
                    ynmin=yn;
                end
            end
            % Check vertical index
            if (ynmin<1)
                ynmin=1;
            end
            if (ynmin>ynum-1)
                ynmin=ynum-1;
            end
            
            % Define indexes for upper left node in the Vx-cell where topography node is
            % Horizontal Vx index
            xn=xnmin;
            % Vertical Vx index
            yn=ynmin;
            if(ycur>gridcy(yn+1))
                yn=yn+1;
            end
            if (yn>ynum)
                yn=ynum;
            end

            % Define and check normalized distances from topography node to the upper left VX-node;
            dx=(xcur-gridx(xn))./xstp1(xn);
            dy=(ycur-gridcy(yn))./ystpc1(yn);

            % Calculate topography point velocity from four surrounding Vx nodes
            gridt(4,i)=gridt(4,i)+(1.0-dx).*(1.0-dy).*vx1(yn,xn);
            gridt(4,i)=gridt(4,i)+(1.0-dx).*dy.*vx1(yn+1,xn);
            gridt(4,i)=gridt(4,i)+dx.*(1.0-dy).*vx1(yn,xn+1);
            gridt(4,i)=gridt(4,i)+dx.*dy.*vx1(yn+1,xn+1);

            % Define indexes for upper left node in the VY-cell where the topography node is
            % Vertical Vy index
            yn=ynmin;
            % Horizontal Vy index
            xn=xnmin;
            if(xcur>gridcx(xn+1))
                xn=xn+1;
            end
            if (xn>xnum)
                xn=xnum;
            end

            % Define and check normalized distances from topography node to the upper left VX-node;
            dx=(xcur-gridcx(xn))./xstpc1(xn);
            dy=(ycur-gridy(yn))./ystp1(yn);

            % Calculate topography node velocity from four surrounding nodes
            gridt(5,i)=gridt(5,i)+(1.0-dx).*(1.0-dy).*vy1(yn,xn);
            gridt(5,i)=gridt(5,i)+(1.0-dx).*dy.*vy1(yn+1,xn);
            gridt(5,i)=gridt(5,i)+dx.*(1.0-dy).*vy1(yn,xn+1);
            gridt(5,i)=gridt(5,i)+dx.*dy.*vy1(yn+1,xn+1);
        end
    end
    
    % Advect topography vertically
    % Diffuse Topography (downhill diffusion)
    % Build topography diffusion matrix
    L=sparse(tnum,tnum);
    R=zeros(tnum,1);
    % First point: symmetry
    L(1,1)=1;
    L(1,2)=-1;
    R(1,1)=0;
    % Intermediate points: dYt/dt=d(Ks*dYt/dx)/dx
    % Yt(i-1)-----Yt(i)-----Yt(i+1)
    % FD representation Yt(i)-Ks*dt*(Yt(i-1)-2*Yt(i)+Yt(i+1))/tstp^2
    for i=2:1:tnum-1
        % Internal points
        if (gridt(1,i)>=gridx(1) && gridt(1,i)<=gridx(xnum));
            % Left part 
            L(i,i-1)=-Ks.*timestep./tstp.^2;
            L(i,i)=1+2*Ks.*timestep./tstp.^2;
            L(i,i+1)=-Ks.*timestep./tstp.^2;
            % Right part, advect topography vertically
            R(i,1)=gridt(2,i)+gridt(5,i).*timestep;
        % External points
        else
            % To the left from the left boundary: symmetry
            if (gridt(1,i)<gridx(1))
                L(i,i)=1;
                L(i,i+1)=-1;
                R(i,1)=0;
            % To the right from the right boundary: symmetry
            else
                L(i,i)=1;
                L(i,i-1)=-1;
                R(i,1)=0;
            end
        end
    end
    % Last point: symmetry
    L(tnum,tnum)=1;
    L(tnum,tnum-1)=-1;
    R(tnum,1)=0;
    % Solve Matrix
    S=L\R;
    % Reload solutions
    for i=1:1:tnum
        gridt(2,i)=S(i);
    end
    
    % Advect topography horizontally
    % Define maximal horizontal velocity at topography nodes
    vxmax=max(abs(gridt(4,:)));
    % Defining topography advection timestep
    dt=timestep;
    nt=1;
    if(vxmax>0)
        dt=tstp/vxmax;
        if (dt<timestep)
            nt=double(int16(timestep./dt-0.5))+1;
            dt=timestep/nt;
        else
            dt=timestep;
        end
    end
    % Defining FCT parameter MU
    mu=1/8;
    % Advect topography with FCT
    for t=1:1:nt
        % Step 0: Set new profile
        gridt(3,:)=gridt(2,:);
        % Step 1: Transport+numerical diffusion stage
        for i=2:1:tnum-1
            % Defining FCT parameters EPS and NU
            eps=gridt(4,i)*dt/tstp;
            nu=1/8+(eps^2)/2;
            % Change topography
            gridt(3,i)=gridt(2,i)-eps/2*(gridt(2,i+1)-gridt(2,i-1))+nu*(gridt(2,i+1)-2*gridt(2,i)+gridt(2,i-1));
        end
        % Step 2: Antidiffusion stage
        % Antidiffusion flow for the first cell
        gridt(6,1)=0;
        for i=2:1:tnum-2
            % Corrected antidiffusion flow for current cell
            delt0=gridt(3,i)-gridt(3,i-1);
            delt1=gridt(3,i+1)-gridt(3,i);
            delt2=gridt(3,i+2)-gridt(3,i+1);
            s=sign(delt1);
            gridt(6,i)=s*max(0,min(min(s*delt2,s*delt0),mu*abs(delt1)));
            gridt(2,i)=gridt(3,i)-gridt(6,i)+gridt(6,i-1);
        end
    end
    
    


    % Interpolating vx, vy for the basic grid
    vxb=zeros(ynum,xnum);
    vyb=zeros(ynum,xnum);
    for j=1:1:xnum
        for i=1:1:ynum
            vxb(i,j)=(vx1(i,j)+vx1(i+1,j))/2;
            vyb(i,j)=(vy1(i,j)+vy1(i,j+1))/2;
        end
    end
    
   
    figure(2), clf;
  
    % Plotting Sxx
    subplot(2,2,1)
    pcolor(gridcx(2:1:xnum)/1000,gridcy(2:1:ynum)/1000,sxx2*1e-6);
    shading interp;
    axis tight;
    title('\sigma_{xx}, MPa')
    colorbar; 
    axis ij image;

    % Plotting Sxy
    subplot(2,2,2)
    pcolor(gridx/1000,gridy/1000,sxy2*1e-6);
    shading interp;
    axis tight;
    title('\sigma_{xy}, MPa')
    colorbar;    
    axis ij image;

    % Plotting Pr
    subplot(2,2,3)
    pcolor(gridcx(2:1:xnum)/1000,gridcy(2:1:ynum)/1000,pr1*1e-9);
    shading interp;
    axis tight;
    title('pressure, GPa')
    colorbar;    
    axis ij image;
    
    % Plotting Eii
    subplot(2,2,4)
    pcolor(gridcx(2:1:xnum)/1000,gridcy(2:1:ynum)/1000,log10(eii));
    shading interp;
    axis tight;
    title('log_{10}(\epsilon_{II}), 1/s')
    colorbar;    
    axis ij image;

    
    % Visualizing marker type
    % Pixel grid resolution
    xresol=double(int16(xsize/500))+1;
    yresol=double(int16(ysize/500))+1;
    ngrid=2;
    sxstp=xsize/(xresol-1);
    systp=ysize/(yresol-1);
    mx=0:sxstp/1000:xsize/1000;
    my=0:systp/1000:ysize/1000;
    % Process markers
    markcom=NaN*ones(yresol,xresol);
    markdis=1e+20*ones(yresol,xresol);
    markgii=zeros(yresol,xresol);
    markbii=zeros(yresol,xresol);
    markmel=NaN*ones(yresol,xresol);
    for mm1 = 1:1:marknum
        % Define pixel cell
        m1=fix((MX(mm1)-gridx(1))/sxstp)+1;
        m2=fix((MY(mm1)-gridy(1))/systp)+1;
        if (m1<1)
            m1=1;
        end
        if (m1>xresol-1)
            m1=xresol-1;
        end
        if (m2<1)
            m2=1;
        end
        if (m2>yresol-1)
            m2=yresol-1;
        end
        % Define indexes of surrounding pixels
        m10min=m1-ngrid;
        if (m10min<1)
            m10min=1;
        end
        m10max=m1+1+ngrid;
        if (m10max>xresol)
            m10max=xresol;
        end
        m20min=m2-ngrid;
        if (m20min<1)
            m20min=1;
        end
        m20max=m2+1+ngrid;
        if (m20max>yresol)
            m20max=yresol;
        end
        % Update pixels around the marker
        for m10 = m10min:1:m10max
            for m20 = m20min:1:m20max 
                % Check distance to current pixel
                dx=(MX(mm1)-gridx(1))-(m10-1)*sxstp;
                dy=(MY(mm1)-gridy(1))-(m20-1)*systp;
                dd=(dx*dx+dy*dy)^0.5;
                if(dd<markdis(m20,m10))
                    markcom(m20,m10)=MI(mm1);
                    markgii(m20,m10)=MGII(mm1);
                    markbii(m20,m10)=MBII(mm1);
                    markmel(m20,m10)=MXM(mm1);
                    markdis(m20,m10)=dd;
                end
            end
        end
    end
    
    % Draw composition
    figure(3), clf;
    subplot(3,2,1)
    pcolor(mx,my,-markcom);
%     colormap(gray);
    shading interp;
    axis ij image;
    title(['rocks']); 
    xlabel('x, km')
    ylabel('y, km')
    
    % Draw melt fraction
    subplot(3,2,2)
    pcolor(mx,my,markmel);
%     colormap(gray);
    colorbar;
    shading interp;
    axis ij image;
    title('melt fraction');
    xlabel('x, km')
    ylabel('y, km')
    
    % Draw bulk strain
    subplot(3,2,3)
    pcolor(mx,my,log10(markbii));
%     colormap(gray);
    colorbar;
    shading interp;
    axis ij image;
    title('log_{10}(bulk strain)');
    xlabel('x, km')
    ylabel('y, km')


    % Draw plastic strain
    subplot(3,2,4)
    pcolor(mx,my,markgii);
%     colormap(gray);
    colorbar;
    shading interp;
    axis ij image;
    title('plastic strain');
    xlabel('x, km')
    ylabel('y, km')
   
    % Stop for 1 second
    drawnow % draw above figure without delay
    pause(1);
    
    
    timesum=timesum
    timestep=timestep
    
    % Advance in time
    timesum=timesum+timestep
    
    ntimestep=ntimestep
    
    % Save topography
    topotime(ntimestep+1,1)=timesum;
    topohigh(ntimestep+1,:)=gridt(2,:);
    topowater(ntimestep+1,1)=waterlev;
    
    
    % Topography
    subplot(3,1,3)
    topolev=zeros(ntimestep+1,tnum);
    for i=1:1:ntimestep+1
        for j=1:1:tnum
            topolev(i,j)=topowater(i)-topohigh(i,j);
        end
    end
    surf(gridt(1,1:1:tnum)/1000,topotime(1:1:ntimestep+1)/(1e+6*365.25*24*3600),topolev(1:1:ntimestep+1,1:1:tnum));
    %      colormap(gray);
    shading interp;
    light;
    lighting phong;
    axis([0 xsize/1000 0 timesum/(1e+6*365.25*24*3600) 0 2000]);
    caxis([-10000 3000]);
    axis ij;
    xlabel('distance, km');
    ylabel('time, Myr');
    zlabel('elevation, m');
    title(['topography evolution, Step=',num2str(ntimestep),' Myr=',num2str(timesum*1e-6/(365.25*24*3600))]); 

    
end