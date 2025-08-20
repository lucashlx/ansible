# 1) Caminho do exe
$Out = 'C:\Windows\Temp\DummyHangSvc.exe'

# 2) Código C# de um serviço que trava no OnStop
$code = @"
using System;
using System.ServiceProcess;
using System.Threading;

public class DummyHangService : ServiceBase
{
    private Thread worker;

    public DummyHangService()
    {
        this.ServiceName = "DummyHangService";
        this.CanStop = true;
        this.CanShutdown = true;
        this.CanPauseAndContinue = false;
        this.AutoLog = true;
    }

    protected override void OnStart(string[] args)
    {
        worker = new Thread(() => { while (true) Thread.Sleep(1000); });
        worker.IsBackground = true;
        worker.Start();
    }

    protected override void OnStop()
    {
        // Simular "stopping" infinito
        Thread.Sleep(Timeout.Infinite);
    }

    public static void Main()
    {
        ServiceBase.Run(new DummyHangService());
    }
}
"@

# 3) Gerar o executável do serviço (sem ferramentas externas)
Add-Type -TypeDefinition $code `
         -ReferencedAssemblies 'System.ServiceProcess.dll' `
         -OutputAssembly $Out `
         -OutputType ConsoleApplication

# 4) Criar o serviço no SCM
sc.exe create DummyHangService binPath= "$Out" start= demand type= own
sc.exe description DummyHangService "Serviço de teste que trava no Stop (simulação de 'Stopping…' eterno)"

# (Opcional) aumentar o timeout do SCM para aparecer "Stopping…" por mais tempo
# HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ServicesPipeTimeout (DWORD em ms)
# Ex.: 180000 = 3 minutos
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'ServicesPipeTimeout' -PropertyType DWord -Value 180000 -Force | Out-Null

# 5) Teste
Start-Service DummyHangService
# Agora tente parar:
# Stop-Service DummyHangService   # <- ficará preso em "Stopping..."
