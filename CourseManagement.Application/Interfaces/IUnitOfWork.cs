namespace CourseManagement.Application.Interfaces;

/// <summary>
/// Groups several repository writes into one atomic database transaction.
/// <para>
/// Repositories each call SaveChanges independently, which is why replacing a course
/// cover was not atomic: the new asset row committed immediately, so a later failure
/// left committed metadata pointing at a file the compensating cleanup had already
/// deleted, and the previous cover row was gone too. All repositories share one
/// scoped DbContext, so a transaction opened here spans every write made through them.
/// </para>
/// </summary>
public interface IUnitOfWork
{
    Task<IUnitOfWorkTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default);
}

/// <summary>
/// Disposing without committing rolls back.
/// </summary>
public interface IUnitOfWorkTransaction : IAsyncDisposable
{
    Task CommitAsync(CancellationToken cancellationToken = default);
}
