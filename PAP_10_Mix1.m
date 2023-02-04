function OUTPUT = PAP_10_Mix1(INPUT)

moda=mode(INPUT.Necesidades_prod);
indice_sim=INPUT.Indice_mix1; %Indice de similitud para la nivelacion

Periodos_niv=(moda*(1-indice_sim)<=INPUT.Necesidades_prod)&(INPUT.Necesidades_prod<=moda*(1+indice_sim));
for i=2:length(Periodos_niv)
   if Periodos_niv(i-1)==1 && Periodos_niv(i+1)==1
      Periodos_niv(i)=1; 
   end
end
Prod_regular=zeros(1,length(INPUT.Necesidades_prod));
%Caza
Prod_regular_c=zeros(1,length(INPUT.Necesidades_prod));%Producción regular
for i=1:length(INPUT.Necesidades_prod)
    if INPUT.Necesidades_prod(i)<=(INPUT.Plantilla_max*INPUT.he_o_d*INPUT.dias_prod(i)/INPUT.he_u_f)
       Prod_regular_c(i)=INPUT.Necesidades_prod(i);
    else
        Prod_regular_c(i)=INPUT.Plantilla_max*INPUT.he_o_d*INPUT.dias_prod(i)/INPUT.he_u_f;
    end
end
Prod_regular_c=(Periodos_niv==0).*Prod_regular_c;

MO_c=zeros(1,length(Prod_regular)); %Mano de obra
C_MO_O_c=zeros(1,length(Prod_regular)); %Costes mano de obra oficiosa

for i=1:length(Prod_regular_c)
   a=ceil(Prod_regular_c(i)*(INPUT.he_u_f/INPUT.dias_prod(i)/INPUT.he_o_d));
   if a>=INPUT.Plantilla_fija
       MO_c(i)=a;
   else
       MO_c(i)=INPUT.Plantilla_fija;
       %Coste de mano de obra oficiosa
       C_MO_O_c(i)=(INPUT.Plantilla_fija*INPUT.dias_prod(i)*INPUT.he_o_d-Prod_regular_c(i)*INPUT.he_u_f)*INPUT.C_mo_o;
   end
   
end

MO_c=(Periodos_niv==0).*MO_c;
Prod_regular_c=floor(INPUT.he_o_d/INPUT.he_u_f*MO_c.*INPUT.dias_prod);%Actualización de la prod reg en funcion del redondeo de MO
C_MO_O_c=(Periodos_niv==0).*C_MO_O_c;

C_MO_c=Prod_regular_c*(INPUT.he_u_f*INPUT.C_mo); %Costes MO

% Nivelacion MO
Horizonte_planif=sum(INPUT.dias_prod.*Periodos_niv); %Horizonte de planificación del PAP en días
Niv_MO=ceil(sum(INPUT.Necesidades_prod.*Periodos_niv)/Horizonte_planif*INPUT.he_u_f/INPUT.he_o_d); %MO necesaria
Prod_regular_niv=floor(Niv_MO*INPUT.he_o_d/INPUT.he_u_f*INPUT.dias_prod).*Periodos_niv;

MO_niv=Niv_MO*ones(1,length(Prod_regular)).*(Periodos_niv==1);%MO
C_MO_niv=Prod_regular_niv*(INPUT.he_u_f*INPUT.C_mo); %Costes MO

%Union caza+niv MO con 100% de nivel de servicio
MO=MO_c+MO_niv;
C_MO=C_MO_c+C_MO_niv;
C_MO_O=C_MO_O_c;
H_MO_regular=INPUT.he_o_d*MO.*INPUT.dias_prod;

Var_MO=zeros(1,length(MO)); %Variación MO
aux1=MO(1)-INPUT.Plantilla;
Var_MO(1)=aux1*(abs(aux1)>=INPUT.Plantilla_fija)+(INPUT.Plantilla_fija-INPUT.Plantilla)*(abs(aux1)<INPUT.Plantilla_fija);
for i=2:length(MO)
   Var_MO(i)=MO(i)-MO(i-1);
end
C_Var_MO=zeros(1,length(MO)); %Costes Variación MO
for i=1:length(Var_MO)
   if Var_MO(i)<=0
       C_Var_MO(i)=INPUT.C_desp*abs(Var_MO(i));
   else
       C_Var_MO(i)=INPUT.C_con*Var_MO(i);
   end
end


Prod_he=zeros(1,length(INPUT.Necesidades_prod));%Producción en horas extra
C_Prod_he=zeros(1,length(INPUT.Necesidades_prod));%Coste prod he
Subcontratacion=zeros(1,length(INPUT.Necesidades_prod));%Subcontratación
C_Sub=zeros(1,length(INPUT.Necesidades_prod)); %Coste subcontratación

C_delta_he=(INPUT.C_mo_ex-INPUT.C_mo)*INPUT.he_u_f; %Coste incremental de MO extra en u.m./unidad


Prod_regular=Prod_regular_c+Prod_regular_niv;
Inventario_final=zeros(1,length(Prod_regular)); %Inventario final
Inventario_final(1)=INPUT.Inv_ini+Prod_regular(1)-INPUT.Necesidades_prod(1);
for i=2:length(Prod_regular)
    Inventario_final(i)=Inventario_final(i-1)+Prod_regular(i)-INPUT.Necesidades_prod(i);
    if Inventario_final(i)<0
       Nec_nc=INPUT.Necesidades_prod(i)-Prod_regular(i)-Inventario_final(i-1);%Necesidades no cubiertas [u]
       if C_delta_he<INPUT.C_sub
           h_ex_disp=INPUT.h_ex_m*(Prod_regular(i)*INPUT.he_u_f); %Horas extra disponibles
           h_ex_todo=min(h_ex_disp,Nec_nc*INPUT.he_u_f);
           Prod_he(i)=floor(h_ex_todo/INPUT.he_u_f); 
           Subcontratacion(i)=Nec_nc-Prod_he(i);
       else
           Subcontratacion(i)=Nec_nc;
       end
       Inventario_final(i)=Inventario_final(i-1)+Prod_regular(i)-INPUT.Necesidades_prod(i)+Prod_he(i)+Subcontratacion(i);
    end
    
end
C_Prod_he=Prod_he*INPUT.he_u_f*INPUT.C_mo_ex;
C_Sub=Subcontratacion*(INPUT.C_mo_ex+INPUT.C_sub);

C_Inv_final=zeros(1,length(Prod_regular)); %Costes inventario final
C_Inv_final(1)=(Inventario_final(1)<0)*INPUT.C_pos*abs(Inventario_final(1))+(Inventario_final(1)<=0)*(Inventario_final(i)+INPUT.Inv_ini)/2*INPUT.C_pos_u;
for i=2:length(C_Inv_final)
   if Inventario_final(i)<0
       C_Inv_final(i)=INPUT.C_pos*abs(Inventario_final(i));
   else
       C_Inv_final(i)=(Inventario_final(i)+Inventario_final(i-1))/2*INPUT.C_pos_u;
   end
end

%Matriz de costes y nivel de servicio
Costes=[C_MO;C_Var_MO;C_Prod_he;C_Sub;C_MO_O;C_Inv_final];
Tabla=[INPUT.Necesidades_prod;INPUT.dias_prod;Prod_regular;Prod_he;Subcontratacion;...
    H_MO_regular;MO;C_MO;C_MO_O;Var_MO;C_Var_MO;C_Prod_he;C_Sub;Inventario_final;C_Inv_final;sum(Costes)];
Coste_total=sum(sum(Costes));
Nivel_servicio=round((sum(Prod_regular)+sum(Prod_he)+sum(Subcontratacion)+sum(Inventario_final.*(Inventario_final<0)))/sum(INPUT.Necesidades_prod)*100,1);

%OUTPUT
OUTPUT=struct('Tabla',Tabla,'Coste_total',Coste_total,'Nivel_servicio',Nivel_servicio);

end