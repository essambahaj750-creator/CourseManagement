using CourseManagement.Domain.Models;

namespace CourseManagement.Application.DTOs;

public sealed class CourseFilterDto
{
    public string? Q { get; set; }
    public int? InstructorId { get; set; }
    public decimal? MinPrice { get; set; }
    public decimal? MaxPrice { get; set; }
    public string? Sort { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 9;

    public CourseSearchCriteria ToCriteria() => new CourseSearchCriteria()
    {
        Query = Q,
        InstructorId = InstructorId,
        MinPrice = MinPrice,
        MaxPrice = MaxPrice,
        SortBy = Sort?.Trim().ToLowerInvariant() switch
        {
            "newest" => CourseSortBy.Newest,
            "price-low" => CourseSortBy.PriceLowToHigh,
            "price-high" => CourseSortBy.PriceHighToLow,
            "title" => CourseSortBy.Title,
            _ => CourseSortBy.Featured
        },
        Page = Page,
        PageSize = PageSize
    }.Normalize();
}

public sealed class CourseCatalogDto
{
    public IReadOnlyList<CourseResponseDto> Items { get; init; } = [];
    public int TotalCount { get; init; }
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int TotalPages => PageSize <= 0 ? 0 : (int)Math.Ceiling(TotalCount / (double)PageSize);
}

public sealed class InstructorOptionDto
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
}
