namespace CourseManagement.Domain.Models;

public enum CourseSortBy
{
    Featured,
    Newest,
    PriceLowToHigh,
    PriceHighToLow,
    Title
}

public sealed record CourseSearchCriteria
{
    public string? Query { get; init; }
    public int? InstructorId { get; init; }
    public decimal? MinPrice { get; init; }
    public decimal? MaxPrice { get; init; }
    public CourseSortBy SortBy { get; init; } = CourseSortBy.Featured;
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = 9;

    public CourseSearchCriteria Normalize()
    {
        var pageSize = Math.Clamp(PageSize, 6, 24);
        var page = Math.Clamp(Page, 1, 10_000);
        var minPrice = MinPrice is >= 0 ? MinPrice : null;
        var maxPrice = MaxPrice is >= 0 ? MaxPrice : null;

        if (minPrice.HasValue && maxPrice.HasValue && minPrice > maxPrice)
            (minPrice, maxPrice) = (maxPrice, minPrice);

        return this with
        {
            Query = string.IsNullOrWhiteSpace(Query) ? null : Query.Trim(),
            MinPrice = minPrice,
            MaxPrice = maxPrice,
            Page = page,
            PageSize = pageSize
        };
    }
}

public sealed record CourseSearchResult(
    IReadOnlyList<CourseManagement.Domain.Entities.Course> Items,
    int TotalCount);

public sealed record CourseInstructorOption(int Id, string Name);
