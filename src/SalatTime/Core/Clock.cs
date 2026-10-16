namespace SalatTime.Core;

/// <summary>The current time, replaceable so screenshots and tests can freeze it.</summary>
public static class Clock
{
    public static Func<DateTime> Now { get; set; } = () => DateTime.Now;
}
